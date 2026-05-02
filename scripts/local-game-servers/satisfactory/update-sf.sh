#!/usr/bin/env bash
# update-sf.sh — Idempotent Satisfactory dedicated server updater (Linux).
# Safe to re-run; resolves install dir and SteamCMD by absolute path; single-instance lock;
# validates markers before/after; optional service stop/start when run as root.
#
# Environment (optional):
#   SATISFACTORY_INSTALL_DIR   Server root (default: /home/steam/sfserver)
#   SATISFACTORY_STEAMCMD      Path to steamcmd binary (auto-detected if unset)
#   SATISFACTORY_BETA          If set to "experimental", passes -beta experimental to SteamCMD.
#                              If unset, tries to infer from /etc/systemd/system/satisfactory.service.
#   SATISFACTORY_SKIP_SERVICE  If 1, do not stop/start systemd (SteamCMD update only; run as steam or root).
#   SATISFACTORY_NO_RESTART    If 1, after update do not start the unit even if it was stopped here.
#   SATISFACTORY_NETWORK_CHECK If 1, fail fast if Steam API is unreachable (optional).
#   SATISFACTORY_HEALTH_CHECK  If 1 after restart, wait briefly for listening game port (optional).
#   SATISFACTORY_UPDATE_LOG    Append structured log lines here (default: /var/log/satisfactory-update.log if writable)
#
# Usage: sudo ./update-sf.sh   [--dry-run]   [--install-dir DIR]
set -euo pipefail

readonly APP_ID="1690800"
readonly DEFAULT_INSTALL_DIR="/home/steam/sfserver"
readonly STEAM_USER="steam"
readonly SERVICE_NAME="satisfactory"
readonly MARKER_REL="FactoryServer.sh"
readonly LOG_TAG="[update-sf]"

DRY_RUN=0
INSTALL_DIR="${SATISFACTORY_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

usage() {
  sed -n '1,25p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'
Options:
  --dry-run          Print actions only; no lock, no SteamCMD, no systemd changes.
  --install-dir DIR  Override install directory for this invocation (same as SATISFACTORY_INSTALL_DIR).
  -h, --help         Show this help.
EOF
}

log_line() {
  local level="$1"
  shift
  local msg="$*"
  msg="${msg//$'\n'/ }"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local line="${ts} ${LOG_TAG} level=${level} msg=${msg}"
  echo "$line" >&2
  if [[ -n "${_UPDATE_LOG_FILE:-}" ]]; then
    local logdir
    logdir="$(dirname "$_UPDATE_LOG_FILE")"
    if [[ -w "$logdir" ]]; then
      echo "$line" >>"$_UPDATE_LOG_FILE" 2>/dev/null || true
    fi
  fi
}

die() {
  log_line "ERROR" "$@"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --install-dir)
      [[ $# -ge 2 ]] || die "--install-dir requires a value"
      INSTALL_DIR="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
  shift
done

# Resolve to absolute path (never depend on caller CWD).
_install_parent="$(dirname "$INSTALL_DIR")"
_install_base="$(basename "$INSTALL_DIR")"
if [[ -d "$_install_parent" ]]; then
  INSTALL_DIR="$(cd "$_install_parent" && pwd)/${_install_base}"
else
  die "parent of install dir does not exist: ${_install_parent}"
fi
unset _install_parent _install_base

# Log file: prefer explicit env, else /var/log if we can write (typically root).
_UPDATE_LOG_FILE="${SATISFACTORY_UPDATE_LOG:-}"
if [[ -z "$_UPDATE_LOG_FILE" ]]; then
  if [[ "${EUID:-$(id -u)}" -eq 0 ]] && [[ -w /var/log ]]; then
    _UPDATE_LOG_FILE="/var/log/satisfactory-update.log"
  fi
fi

log_line "INFO" "starting install_dir=${INSTALL_DIR} dry_run=${DRY_RUN} euid=${EUID:-$(id -u)}"

# Resolve SteamCMD: explicit > steam home symlink > distro path.
STEAMCMD="${SATISFACTORY_STEAMCMD:-}"
if [[ -z "$STEAMCMD" ]]; then
  if [[ -x "/home/${STEAM_USER}/steamcmd" ]]; then
    STEAMCMD="/home/${STEAM_USER}/steamcmd"
  elif [[ -x "/usr/games/steamcmd" ]]; then
    STEAMCMD="/usr/games/steamcmd"
  else
    STEAMCMD=""
  fi
fi

# steam user (required on real run).
if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -n "$STEAMCMD" && -x "$STEAMCMD" ]] || die "steamcmd not found or not executable; set SATISFACTORY_STEAMCMD or install steamcmd (apt install steamcmd)"
  id "${STEAM_USER}" &>/dev/null || die "Linux user '${STEAM_USER}' does not exist (run satisfactory.sh first)"
else
  [[ -n "$STEAMCMD" && -x "$STEAMCMD" ]] || log_line "WARN" "dry-run: steamcmd not found (real run would fail here)"
  id "${STEAM_USER}" &>/dev/null || log_line "WARN" "dry-run: user '${STEAM_USER}' missing (real run would fail here)"
fi

# Beta branch: env wins, else infer from systemd unit if present.
BETA_FLAG=""
if [[ "${SATISFACTORY_BETA:-}" == "experimental" ]]; then
  BETA_FLAG="-beta experimental"
elif [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] && grep -qE '[[:space:]]-beta[[:space:]]+experimental' "/etc/systemd/system/${SERVICE_NAME}.service" 2>/dev/null; then
  BETA_FLAG="-beta experimental"
fi
log_line "INFO" "steamcmd=${STEAMCMD:-<unset>} beta_flag=${BETA_FLAG:-<none>}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ -d "$INSTALL_DIR" ]] || log_line "WARN" "dry-run: install directory missing: ${INSTALL_DIR}"
  [[ -f "${INSTALL_DIR}/${MARKER_REL}" ]] || log_line "WARN" "dry-run: marker ${MARKER_REL} missing under ${INSTALL_DIR}"
  log_line "INFO" "dry-run: would optional network check; flock ${INSTALL_DIR}/.update-sf.lock; stop ${SERVICE_NAME} if active (as root); sudo -u ${STEAM_USER} steamcmd app_update ${APP_ID} validate; verify marker; start unit if this run stopped it"
  exit 0
fi

# Optional network gate (Steam Web API).
if [[ "${SATISFACTORY_NETWORK_CHECK:-0}" == "1" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    die "SATISFACTORY_NETWORK_CHECK=1 requires curl"
  fi
  if ! curl -fsS --max-time 15 "https://api.steampowered.com/ISteamApps/GetAppList/v2/" >/dev/null; then
    die "network check failed: cannot reach Steam API (SATISFACTORY_NETWORK_CHECK=1)"
  fi
  log_line "INFO" "network check ok (Steam API reachable)"
fi

# Pre-flight: install dir exists and marker present (fail fast — wrong directory).
[[ -d "$INSTALL_DIR" ]] || die "install directory missing: ${INSTALL_DIR}"
MARKER_PATH="${INSTALL_DIR}/${MARKER_REL}"
[[ -f "$MARKER_PATH" ]] || die "marker missing (wrong install dir?): ${MARKER_PATH}"

# Ownership: warn if not steam (updates still run as steam).
owner_uid="$(stat -c '%u' "$INSTALL_DIR" 2>/dev/null || stat -f '%u' "$INSTALL_DIR")"
steam_uid="$(id -u "${STEAM_USER}")"
if [[ "$owner_uid" != "$steam_uid" ]]; then
  log_line "WARN" "install_dir owner uid=${owner_uid} expected steam uid=${steam_uid}; continuing (SteamCMD runs as ${STEAM_USER})"
fi

LOCK_FILE="${INSTALL_DIR}/.update-sf.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  die "another update holds the lock (${LOCK_FILE}); try again later"
fi
log_line "INFO" "acquired lock ${LOCK_FILE}"

STOPPED_BY_US=0
cleanup_restart() {
  local ec=$?
  if [[ "${SATISFACTORY_SKIP_SERVICE:-0}" == "1" ]]; then
    flock -u 9 || true
    exit "$ec"
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    flock -u 9 || true
    exit "$ec"
  fi
  if [[ "$STOPPED_BY_US" -eq 1 && "${SATISFACTORY_NO_RESTART:-0}" != "1" && "$ec" -eq 0 ]]; then
    log_line "INFO" "starting unit ${SERVICE_NAME}"
    if ! systemctl start "${SERVICE_NAME}"; then
      log_line "WARN" "systemctl start ${SERVICE_NAME} failed"
    fi
    if [[ "${SATISFACTORY_HEALTH_CHECK:-0}" == "1" ]]; then
      sleep 3
      if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ':7777'; then
          log_line "INFO" "health check: something listening on 7777/tcp or udp"
        else
          log_line "WARN" "health check: no listener on 7777 yet (game may still be starting)"
        fi
      else
        log_line "WARN" "health check skipped (ss not installed)"
      fi
    fi
  fi
  flock -u 9 || true
  exit "$ec"
}
trap cleanup_restart EXIT

# Service lifecycle: only as root when not skipped.
if [[ "${SATISFACTORY_SKIP_SERVICE:-0}" != "1" ]] && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    log_line "INFO" "stopping ${SERVICE_NAME} for update"
    systemctl stop "${SERVICE_NAME}" || die "systemctl stop ${SERVICE_NAME} failed"
    STOPPED_BY_US=1
  else
    log_line "INFO" "unit ${SERVICE_NAME} not active; no stop needed"
  fi
elif [[ "${SATISFACTORY_SKIP_SERVICE:-0}" != "1" ]] && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  log_line "WARN" "not root: cannot stop/start ${SERVICE_NAME}; ensure server is stopped before update or set SATISFACTORY_SKIP_SERVICE=1"
fi

log_line "INFO" "running SteamCMD app_update ${APP_ID} validate"
# shellcheck disable=SC2086
if ! sudo -u "${STEAM_USER}" -- "$STEAMCMD" \
  +force_install_dir "$INSTALL_DIR" \
  +login anonymous \
  +app_update "${APP_ID}" ${BETA_FLAG} validate \
  +quit; then
  die "SteamCMD app_update failed"
fi

[[ -f "$MARKER_PATH" ]] || die "post-update validation failed: missing ${MARKER_PATH}"

log_line "INFO" "update complete install_dir=${INSTALL_DIR}"
