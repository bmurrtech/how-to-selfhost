#!/usr/bin/env bash
# reset-admin-pw.sh — Satisfactory dedicated server: admin password reset or diagnostics (Linux).
# Matches layouts from satisfactory.sh / update-sf.sh (steam user, Epic SaveGames path).
#
# There is no supported API to read the in-game admin password from ServerSettings.*.sav
# (binary). Option 1 follows the official reset: remove ServerSettings after backup, reclaim in client.
# Option 2 lists files, scans plaintext *.ini under Saved for known keys, optional strings(1) dump.
#
# Requires root (sudo) for systemctl stop/start and archive ownership.
#
# Environment:
#   SATISFACTORY_STEAM_USER   Linux user running the server (default: steam)
#   SATISFACTORY_ARCHIVE_DIR  Backup directory (default: /home/steam/satisfactory-save-archives)
#
set -euo pipefail

readonly SERVICE_NAME="satisfactory"
STEAM_USER="${SATISFACTORY_STEAM_USER:-steam}"
STEAM_HOME="/home/${STEAM_USER}"
SAVE_GAMES="${STEAM_HOME}/.config/Epic/FactoryGame/Saved/SaveGames"
ARCHIVE_DIR="${SATISFACTORY_ARCHIVE_DIR:-${STEAM_HOME}/satisfactory-save-archives}"
SAVED_ROOT="${STEAM_HOME}/.config/Epic/FactoryGame/Saved"

usage() {
  cat <<'EOF'
Usage: sudo ./reset-admin-pw.sh

Interactive:
  1) Reset in-game admin password — backs up then deletes ServerSettings.<port>.sav, restarts
     the service so you can reclaim the server in the client (new admin password).
  2) Inspect / recover hints — lists ServerSettings files, scans Saved/**/*.ini for plaintext
     password-like keys (if any). Does NOT print a guaranteed admin password from .sav.

Deleting ServerSettings resets server UI settings (name, session, etc.); world saves under
SaveGames/server/ are kept. Still back up SaveGames before option 1 if the world matters.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[reset-admin-pw] $*" >&2; }

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "run as root: sudo $0"
fi

id "${STEAM_USER}" &>/dev/null || die "Linux user '${STEAM_USER}' not found"

if [[ ! -d "$SAVE_GAMES" ]]; then
  die "SaveGames directory missing: ${SAVE_GAMES} (has the server been started at least once?)"
fi

mapfile -t SERVER_SETTINGS < <(find "$SAVE_GAMES" -maxdepth 1 -type f -name 'ServerSettings.*.sav' 2>/dev/null | sort || true)

echo "" >&2
echo "Satisfactory — admin password / ServerSettings" >&2
echo "  SaveGames: ${SAVE_GAMES}" >&2
echo "  User:      ${STEAM_USER}" >&2
echo "" >&2
echo "Choose:" >&2
echo "  1) Reset admin password — backup ServerSettings*.sav, delete them, restart ${SERVICE_NAME}" >&2
echo "     (then reclaim in-game: Server Manager → add server → set new admin password)" >&2
echo "  2) Inspect — list ServerSettings files; scan Saved/**/*.ini for plaintext keys;" >&2
echo "     optional strings(1) on .sav (no guarantee of real password)" >&2
read -r -p "Enter 1 or 2: " choice

case "${choice:-}" in
  1) ACTION=reset ;;
  2) ACTION=inspect ;;
  *) die "invalid choice (use 1 or 2)" ;;
esac

ensure_archive_dir() {
  mkdir -p "$ARCHIVE_DIR"
  chown "${STEAM_USER}:${STEAM_USER}" "$ARCHIVE_DIR" 2>/dev/null || true
}

stop_service() {
  if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    log "stopping ${SERVICE_NAME}"
    systemctl stop "${SERVICE_NAME}"
  else
    log "unit ${SERVICE_NAME} not active"
  fi
}

start_service() {
  log "starting ${SERVICE_NAME}"
  systemctl start "${SERVICE_NAME}" || die "systemctl start failed"
}

do_reset() {
  if [[ "${#SERVER_SETTINGS[@]}" -eq 0 ]]; then
    echo "No ServerSettings.*.sav files under ${SAVE_GAMES}." >&2
    echo "Expected names like ServerSettings.7777.sav or ServerSettings.15777.sav (port-specific)." >&2
    echo "Start the server once from the game client or check a custom data directory." >&2
    exit 1
  fi

  echo "" >&2
  echo "WARNING: Removing ServerSettings.*.sav resets server manager settings (name, session," >&2
  echo "auto-load session, certificates, etc.). World saves in server/ are NOT deleted by this script." >&2
  echo "Files to remove:" >&2
  printf '  %s\n' "${SERVER_SETTINGS[@]}" >&2
  read -r -p "Type YES to continue with backup + delete: " confirm
  [[ "${confirm:-}" == "YES" ]] || die "aborted (must type YES)"

  ensure_archive_dir
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local buck="${ARCHIVE_DIR}/ServerSettings-preserver-${stamp}"
  mkdir -p "$buck"
  chown "${STEAM_USER}:${STEAM_USER}" "$buck"

  stop_service
  for f in "${SERVER_SETTINGS[@]}"; do
    local base
    base="$(basename "$f")"
    log "backing up ${base}"
    cp -a "$f" "${buck}/${base}"
    chown "${STEAM_USER}:${STEAM_USER}" "${buck}/${base}"
    rm -f "$f"
    log "removed ${base}"
  done
  start_service

  echo "" >&2
  echo "Done. Backup directory: ${buck}" >&2
  echo "Next steps (client):" >&2
  echo "  1) Satisfactory → Server Manager → Add Server (IP:query port, often :15777)." >&2
  echo "  2) Connect — claim server and enter a NEW admin password twice." >&2
  echo "  3) Server Settings → authenticate → restore name / auto-load session as needed." >&2
}

scan_ini_for_plaintext_hints() {
  [[ -d "$SAVED_ROOT" ]] || return 0
  local hits=0
  while IFS= read -r -d '' ini; do
    if grep -Eiq '^(ServerAdminPassword|AdminPassword|Password|GamePassword)\s*=' "$ini" 2>/dev/null; then
      echo "--- Possible plaintext key in: $ini ---" >&2
      grep -Ein '^(ServerAdminPassword|AdminPassword|Password|GamePassword)\s*=' "$ini" 2>/dev/null | head -20 >&2
      hits=1
    fi
  done < <(find "$SAVED_ROOT" -type f \( -name '*.ini' -o -name '*.cfg' \) -print0 2>/dev/null || true)
  if [[ "$hits" -eq 0 ]]; then
    echo "No obvious plaintext admin/password keys in *.ini / *.cfg under ${SAVED_ROOT}." >&2
  fi
}

do_inspect() {
  echo "" >&2
  echo "=== ServerSettings.*.sav (Epic layout) ===" >&2
  if [[ "${#SERVER_SETTINGS[@]}" -eq 0 ]]; then
    echo "(none found under ${SAVE_GAMES})" >&2
  else
    for f in "${SERVER_SETTINGS[@]}"; do
      ls -la "$f" >&2
    done
  fi

  echo "" >&2
  echo "=== Plaintext config scan (best-effort) ===" >&2
  scan_ini_for_plaintext_hints

  echo "" >&2
  echo "NOTE: Satisfactory stores the dedicated admin secret in ServerSettings.<port>.sav in a" >&2
  echo "binary format. This script cannot securely or reliably print that password." >&2
  echo "Use option 1 to reset, then reclaim in the game client." >&2

  read -r -p "Run strings(1) on newest ServerSettings*.sav for debugging (noisy, may be empty)? [y/N]: " do_strings
  if [[ "${do_strings:-}" =~ ^[Yy]$ ]] && [[ "${#SERVER_SETTINGS[@]}" -gt 0 ]]; then
    local newest="${SERVER_SETTINGS[0]}"
    local f
    for f in "${SERVER_SETTINGS[@]}"; do
      [[ "$f" -nt "$newest" ]] && newest="$f"
    done
    [[ -n "$newest" ]] || return 0
    if ! command -v strings >/dev/null 2>&1; then
      echo "strings(1) not installed (apt install binutils)." >&2
      return 0
    fi
    echo "" >&2
    echo "--- strings -n 12 \"$newest\" (first 80 lines; NOT verified as password) ---" >&2
    strings -n 12 "$newest" 2>/dev/null | head -80 >&2 || true
  fi
}

case "$ACTION" in
  reset) do_reset ;;
  inspect) do_inspect ;;
esac

exit 0
