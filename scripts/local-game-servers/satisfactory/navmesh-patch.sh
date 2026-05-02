#!/usr/bin/env bash
# navmesh-patch.sh — Mitigate Satisfactory dedicated "Navmesh bounds are too large" log spam / load
# on large saves (post–Update 8+). Stops the unit, backs up Engine.ini, ensures Unreal nav setting:
#   [/Script/Engine.NavigationSystemV1]
#   bGenerateNavigationOnlyAroundNavigationInvokers=True
# under LinuxServer config, then restarts satisfactory.
#
# Optional: run SteamCMD validate after patch (--validate) to rule out corrupt game files.
#
# Requires root. Install dir default /home/steam/sfserver (SATISFACTORY_INSTALL_DIR).
#
set -euo pipefail

readonly SERVICE_NAME="satisfactory"
readonly STEAM_USER="${SATISFACTORY_STEAM_USER:-steam}"
readonly STEAM_HOME="/home/${STEAM_USER}"
INSTALL_DIR="${SATISFACTORY_INSTALL_DIR:-/home/steam/sfserver}"
readonly NAV_SECTION='[/Script/Engine.NavigationSystemV1]'
readonly NAV_KEY='bGenerateNavigationOnlyAroundNavigationInvokers=True'
readonly APP_ID="1690800"

DRY_RUN=0
RUN_VALIDATE=0

usage() {
  cat <<'EOF'
Usage: sudo ./navmesh-patch.sh [options]

Stops satisfactory, patches Engine.ini (LinuxServer) with NavigationSystemV1 nav invoker tweak,
optionally runs SteamCMD validate, restarts satisfactory.

Options:
  --dry-run       Print actions only (no stop, no file writes, no SteamCMD).
  --install-dir D Override game install root (default /home/steam/sfserver).
  --validate      After ini patch, run SteamCMD app_update ... validate (same app as setup).
  -h, --help      This help.

Env: SATISFACTORY_INSTALL_DIR, SATISFACTORY_STEAM_USER, SATISFACTORY_BETA=experimental
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[navmesh-patch] $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --install-dir)
      [[ $# -ge 2 ]] || die "--install-dir needs a value"
      INSTALL_DIR="$2"
      shift
      ;;
    --validate) RUN_VALIDATE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "run as root: sudo $0"
fi

id "${STEAM_USER}" &>/dev/null || die "user ${STEAM_USER} not found"

_install_parent="$(dirname "$INSTALL_DIR")"
_install_base="$(basename "$INSTALL_DIR")"
[[ -d "$_install_parent" ]] || die "bad install path parent: ${_install_parent}"
INSTALL_DIR="$(cd "$_install_parent" && pwd)/${_install_base}"

INI_INSTALL="${INSTALL_DIR}/FactoryGame/Saved/Config/LinuxServer/Engine.ini"
INI_EPIC="${STEAM_HOME}/.config/Epic/FactoryGame/Saved/Config/LinuxServer/Engine.ini"

BETA_FLAG=""
if [[ "${SATISFACTORY_BETA:-}" == "experimental" ]]; then
  BETA_FLAG="-beta experimental"
elif [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] && grep -qE '[[:space:]]-beta[[:space:]]+experimental' "/etc/systemd/system/${SERVICE_NAME}.service" 2>/dev/null; then
  BETA_FLAG="-beta experimental"
fi

STEAMCMD=""
if [[ -x "${STEAM_HOME}/steamcmd" ]]; then
  STEAMCMD="${STEAM_HOME}/steamcmd"
elif [[ -x /usr/games/steamcmd ]]; then
  STEAMCMD=/usr/games/steamcmd
fi

patch_engine_ini() {
  local f="$1"
  local dir stamp
  dir="$(dirname "$f")"
  stamp="$(date +%Y%m%d-%H%M%S)"

  if [[ -f "$f" ]] && grep -qF "bGenerateNavigationOnlyAroundNavigationInvokers=True" "$f" 2>/dev/null; then
    log "skip (already has nav key =True): $f"
    return 0
  fi

  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.${stamp}"
    chown "${STEAM_USER}:${STEAM_USER}" "${f}.bak.${stamp}"
    log "backup ${f}.bak.${stamp}"
  fi

  mkdir -p "$dir"
  if [[ ! -f "$f" ]]; then
    log "creating $f"
    : >"$f"
    chown "${STEAM_USER}:${STEAM_USER}" "$f"
    chmod 644 "$f"
  fi

  {
    echo ""
    echo "$NAV_SECTION"
    echo "$NAV_KEY"
  } >>"$f"
  chown "${STEAM_USER}:${STEAM_USER}" "$f"
  log "appended nav section to $f"
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run: would stop ${SERVICE_NAME}, patch:"
  log "  $INI_INSTALL"
  [[ -f "$INI_EPIC" ]] && log "  $INI_EPIC"
  [[ "$RUN_VALIDATE" -eq 1 ]] && log "  then steamcmd validate (beta=${BETA_FLAG:-none})"
  log "dry-run: would start ${SERVICE_NAME}"
  exit 0
fi

if [[ "$RUN_VALIDATE" -eq 1 ]]; then
  [[ -n "$STEAMCMD" && -x "$STEAMCMD" ]] || die "steamcmd not found (install steamcmd or drop --validate)"
fi

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
  log "stopping ${SERVICE_NAME}"
  systemctl stop "${SERVICE_NAME}"
else
  log "unit ${SERVICE_NAME} not active"
fi

patch_engine_ini "$INI_INSTALL"
if [[ -f "$INI_EPIC" ]]; then
  patch_engine_ini "$INI_EPIC"
fi

if [[ "$RUN_VALIDATE" -eq 1 ]]; then
  log "running SteamCMD validate for app ${APP_ID}"
  # shellcheck disable=SC2086
  sudo -u "${STEAM_USER}" -- "$STEAMCMD" \
    +force_install_dir "$INSTALL_DIR" \
    +login anonymous \
    +app_update "${APP_ID}" ${BETA_FLAG} validate \
    +quit
fi

log "starting ${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}" || die "systemctl start failed"

echo "" >&2
echo "Patch applied. Monitor logs:" >&2
echo "  sudo journalctl -u satisfactory -f" >&2
echo "  sudo tail -f /var/log/satisfactory.log" >&2
exit 0
