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
#   SATISFACTORY_NO_RESTART    If 1, after a successful update do not restart the unit (default is restart when root).
#   SATISFACTORY_NETWORK_CHECK If 1, fail fast if Steam API is unreachable (optional).
#   SATISFACTORY_HEALTH_CHECK  If 1 after restart, wait briefly for listening game port (optional).
#   SATISFACTORY_UPDATE_LOG       Append structured log lines here (default: /var/log/satisfactory-update.log if writable)
#   SATISFACTORY_SAVE_ARCHIVE_DIR Directory for SaveGames .bak copies + .tar.gz (default: /home/steam/satisfactory-save-archives)
#   SATISFACTORY_SKIP_SAVE_BACKUP If 1, skip SaveGames archive before SteamCMD
#
# Usage: sudo ./update-sf.sh   [--dry-run]   [--install-dir DIR]
set -euo pipefail

readonly APP_ID="1690800"
readonly DEFAULT_INSTALL_DIR="/home/steam/sfserver"
readonly STEAM_USER="steam"
readonly SERVICE_NAME="satisfactory"
readonly MARKER_REL="FactoryServer.sh"
readonly LOG_TAG="[update-sf]"
STEAM_HOME="/home/${STEAM_USER}"
SAVE_SG="${STEAM_HOME}/.config/Epic/FactoryGame/Saved/SaveGames"
LAST_SAVE_BACKUP_PATH=""

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

# Read Steam appmanifest for debug (buildid / betakey). Paths relative to force_install_dir.
read_manifest_field() {
  local mf="$1" key="$2"
  local line
  [[ -f "$mf" ]] || { echo ""; return 0; }
  line="$(grep -m1 "\"${key}\"" "$mf" 2>/dev/null || true)"
  [[ -z "$line" ]] && { echo ""; return 0; }
  sed -E "s/.*\"${key}\"[[:space:]]+\"([^\"]*)\".*/\\1/" <<<"$line" | tr -d '\r'
}

log_manifest_state() {
  local phase="$1"
  local mf="${INSTALL_DIR}/steamapps/appmanifest_${APP_ID}.acf"
  if [[ ! -f "$mf" ]]; then
    log_line "WARN" "${phase}: no appmanifest at ${mf} (cannot log Steam buildid)"
    return 0
  fi
  local buildid betakey
  buildid="$(read_manifest_field "$mf" "buildid")"
  betakey="$(read_manifest_field "$mf" "betakey")"
  log_line "INFO" "${phase} steam_app=${APP_ID} buildid=${buildid:-unknown} betakey=${betakey:-} (empty betakey = public branch)"
}

read_build_version_field() {
  local f="$1" key="$2"
  local line
  [[ -f "$f" ]] || { echo ""; return 0; }
  line="$(grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]+" "$f" 2>/dev/null | head -1 || true)"
  [[ -z "$line" ]] && { echo ""; return 0; }
  grep -oE '[0-9]+$' <<<"$line"
}

backup_satisfactory_saves() {
  [[ "${SATISFACTORY_SKIP_SAVE_BACKUP:-0}" == "1" ]] && {
    log_line "INFO" "skipping SaveGames backup (SATISFACTORY_SKIP_SAVE_BACKUP=1)"
    return 0
  }
  local archive_dir="${SATISFACTORY_SAVE_ARCHIVE_DIR:-${STEAM_HOME}/satisfactory-save-archives}"
  mkdir -p "$archive_dir"
  chown "${STEAM_USER}:${STEAM_USER}" "$archive_dir" 2>/dev/null || true
  if [[ ! -d "$SAVE_SG" ]]; then
    log_line "INFO" "no SaveGames dir yet (${SAVE_SG}); nothing to archive"
    return 0
  fi
  local stamp dest
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="${archive_dir}/SaveGames-${stamp}.bak"
  log_line "INFO" "archiving SaveGames -> ${dest} and SaveGames-${stamp}.tar.gz"
  cp -a "$SAVE_SG" "$dest"
  chown -R "${STEAM_USER}:${STEAM_USER}" "$dest"
  tar -czf "${archive_dir}/SaveGames-${stamp}.tar.gz" -C "$(dirname "$SAVE_SG")" "$(basename "$SAVE_SG")"
  chown "${STEAM_USER}:${STEAM_USER}" "${archive_dir}/SaveGames-${stamp}.tar.gz"
  LAST_SAVE_BACKUP_PATH="$dest"
}

restore_saves_if_needed() {
  [[ -z "${LAST_SAVE_BACKUP_PATH}" ]] && return 0
  local bak_sav=0
  [[ -d "${LAST_SAVE_BACKUP_PATH}/server" ]] && bak_sav=$(find "${LAST_SAVE_BACKUP_PATH}/server" -maxdepth 1 -name '*.sav' 2>/dev/null | wc -l)
  [[ "$bak_sav" -eq 0 ]] && return 0
  mkdir -p "$SAVE_SG"
  local n_after=0
  [[ -d "${SAVE_SG}/server" ]] && n_after=$(find "${SAVE_SG}/server" -maxdepth 1 -name '*.sav' 2>/dev/null | wc -l)
  if [[ "$n_after" -eq 0 ]]; then
    log_line "WARN" "no .sav under ${SAVE_SG}/server after update; restoring from ${LAST_SAVE_BACKUP_PATH}"
    cp -a "${LAST_SAVE_BACKUP_PATH}/." "$SAVE_SG/"
    chown -R "${STEAM_USER}:${STEAM_USER}" "$SAVE_SG"
    log_line "INFO" "SaveGames restored from backup"
  fi
}

print_installed_version_banner() {
  local mf="${INSTALL_DIR}/steamapps/appmanifest_${APP_ID}.acf"
  local bid bv maj min pat cl
  bid="$(read_manifest_field "$mf" "buildid")"
  bv="$(find "$INSTALL_DIR" -name 'Build.version' -print -quit 2>/dev/null || true)"
  maj=""; min=""; pat=""; cl=""
  if [[ -n "$bv" ]]; then
    maj="$(read_build_version_field "$bv" MajorVersion)"
    min="$(read_build_version_field "$bv" MinorVersion)"
    pat="$(read_build_version_field "$bv" PatchVersion)"
    cl="$(read_build_version_field "$bv" Changelist)"
  fi
  local branch="public (stable)"
  [[ -n "$BETA_FLAG" ]] && branch="Experimental"
  local eng_line="  Engine Build.version not found under ${INSTALL_DIR} (normal on some layouts)."
  if [[ -n "$maj" || -n "$cl" ]]; then
    eng_line="  Engine (approx):  ${maj:-?}.${min:-?}.${pat:-?}  Changelist: ${cl:-?}"
  fi
  printf '%s\n' \
    "" \
    "======== Satisfactory dedicated server — installed version ========" \
    "  Steam branch:     ${branch}" \
    "  Steam buildid:    ${bid:-unknown}   (appmanifest ${APP_ID})" \
    "$eng_line" \
    "  Compare to your Steam client: Library → Satisfactory → Properties → Updates / Betas." \
    "======================================================================" \
    ""
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
if [[ -n "$BETA_FLAG" ]]; then
  log_line "INFO" "server Steam branch: Experimental — game client must use Satisfactory Experimental to match"
else
  log_line "INFO" "server Steam branch: public (stable) — game client must use the default non-Experimental branch to match"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ -d "$INSTALL_DIR" ]] || log_line "WARN" "dry-run: install directory missing: ${INSTALL_DIR}"
  [[ -f "${INSTALL_DIR}/${MARKER_REL}" ]] || log_line "WARN" "dry-run: marker ${MARKER_REL} missing under ${INSTALL_DIR}"
  log_line "INFO" "dry-run: would optional network check; flock; stop if active; archive SaveGames to .bak/.tar.gz; steamcmd validate; restore saves if missing; print version banner; systemctl restart on success (root)"
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

SERVICE_WAS_ACTIVE=0
if [[ "${SATISFACTORY_SKIP_SERVICE:-0}" != "1" ]] && [[ "${EUID:-$(id -u)}" -eq 0 ]] && systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
  SERVICE_WAS_ACTIVE=1
fi

cleanup_restart() {
  local ec=$?
  if [[ "${SATISFACTORY_SKIP_SERVICE:-0}" == "1" ]]; then
    flock -u 9 || true
    exit "$ec"
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if [[ "$ec" -eq 0 ]]; then
      log_line "WARN" "updated files on disk but not root: could not restart ${SERVICE_NAME}. If the game still says incompatible version, run: sudo systemctl restart ${SERVICE_NAME} (old process may still be running)."
    fi
    flock -u 9 || true
    exit "$ec"
  fi
  # Always restart on success so the running process reloads new binaries (covers was-active and was-inactive).
  if [[ "$ec" -eq 0 && "${SATISFACTORY_NO_RESTART:-0}" != "1" ]]; then
    log_line "INFO" "restarting ${SERVICE_NAME} so the server process matches updated files (was_active_before_update=${SERVICE_WAS_ACTIVE})"
    if ! systemctl restart "${SERVICE_NAME}"; then
      log_line "WARN" "systemctl restart ${SERVICE_NAME} failed"
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

# Service lifecycle: only as root when not skipped — stop before touching files if the unit is running.
if [[ "${SATISFACTORY_SKIP_SERVICE:-0}" != "1" ]] && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  if [[ "$SERVICE_WAS_ACTIVE" -eq 1 ]]; then
    log_line "INFO" "stopping ${SERVICE_NAME} for safe file update"
    systemctl stop "${SERVICE_NAME}" || die "systemctl stop ${SERVICE_NAME} failed"
  else
    log_line "INFO" "unit ${SERVICE_NAME} not active before update; files will update without a prior stop"
  fi
elif [[ "${SATISFACTORY_SKIP_SERVICE:-0}" != "1" ]] && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  log_line "WARN" "not root: cannot stop/restart ${SERVICE_NAME}; use sudo for a full update or stop the server manually before running"
fi

backup_satisfactory_saves

STEAM_MANIFEST="${INSTALL_DIR}/steamapps/appmanifest_${APP_ID}.acf"
PRE_BUILDID="$(read_manifest_field "$STEAM_MANIFEST" "buildid")"
log_manifest_state "pre_steamcmd"

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

POST_BUILDID="$(read_manifest_field "$STEAM_MANIFEST" "buildid")"
log_manifest_state "post_steamcmd"
if [[ -n "$PRE_BUILDID" && -n "$POST_BUILDID" && "$PRE_BUILDID" == "$POST_BUILDID" ]]; then
  log_line "WARN" "buildid unchanged (${POST_BUILDID}): Steam may already be latest, or login/update failed silently. In-game incompatible version is very often stable vs Experimental mismatch — match Steam client branch to server (see beta_flag logs above)."
fi

restore_saves_if_needed
print_installed_version_banner

log_line "INFO" "update complete install_dir=${INSTALL_DIR}"
