#!/bin/bash
# host-palworld-fix.sh — Fix co-op host save (000...001) on a dedicated server after import.
# Run AFTER import-palworld-save.sh and after the host has created a new character on the server.
# Interactive only: detects world and player saves, lets you choose which file is the host original
# and which is the new character; patches save data so the server loads the host character.
# Requires: root, Python 3 (stdlib only; no pip packages). No DedicatedServerName changes.
# Usage: sudo ./host-palworld-fix.sh
# Logic inspired by https://github.com/xNul/palworld-host-save-fix (MIT).

set -euo pipefail

PAL_INSTALL_DIR="${PAL_INSTALL_DIR:-/home/steam/palserver}"
SAVE_BASE="$PAL_INSTALL_DIR/Pal/Saved/SaveGames/0"
# Co-op/single-player host save ID (game constant); default "original" choice. Not PII.
HOST_SAVE_DEFAULT="00000000000000000000000000000001"

log() { echo "[host-palworld-fix] $*"; }
log_err() { echo "[host-palworld-fix] $*" >&2; }

# Resolve world folder: first directory under SaveGames/0, excluding backup folders (.bak).
# Import and host-fix scripts create backups like <world>.bak-<timestamp>; we must use the
# live world so all current player .sav files (including 000...001) are listed.
resolve_world_folder() {
  local first
  first="$(find "$SAVE_BASE" -maxdepth 1 -type d ! -path "$SAVE_BASE" ! -name '*.bak*' 2>/dev/null | sort | head -1)"
  if [[ -n "$first" ]]; then
    basename "$first"
  else
    echo ""
  fi
}

if [[ "$EUID" -ne 0 ]]; then
  log_err "This script must be run as root (sudo)."
  exit 1
fi

if [[ ! -d "$SAVE_BASE" ]]; then
  log_err "Save base not found: $SAVE_BASE. Is Palworld installed and has the server been run once?"
  exit 1
fi

WORLD_FOLDER="$(resolve_world_folder)"
if [[ -z "$WORLD_FOLDER" ]]; then
  log_err "No world folder found under $SAVE_BASE."
  exit 1
fi

WORLD_PATH="$SAVE_BASE/$WORLD_FOLDER"
PLAYERS_DIR="$WORLD_PATH/Players"

if [[ ! -d "$WORLD_PATH" ]] || [[ ! -d "$PLAYERS_DIR" ]] || [[ ! -f "$WORLD_PATH/Level.sav" ]]; then
  log_err "World or Players or Level.sav not found under $WORLD_PATH."
  exit 1
fi

# Build list of player .sav files (basenames without .sav), sorted; default first = 000...001
PLAYER_SAVS=()
for f in "$PLAYERS_DIR"/*.sav; do
  [[ -f "$f" ]] && PLAYER_SAVS+=("$(basename "$f" .sav)")
done
if [[ ${#PLAYER_SAVS[@]} -eq 0 ]]; then
  log_err "No .sav files in $PLAYERS_DIR."
  exit 1
fi
mapfile -t PLAYER_SAVS < <(printf '%s\n' "${PLAYER_SAVS[@]}" | sort)

# Default indices: 1 = host original (000...001), 2 = new character (first other)
DEFAULT_OLD_IDX=1
DEFAULT_NEW_IDX=2
for i in "${!PLAYER_SAVS[@]}"; do
  if [[ "${PLAYER_SAVS[$i]}" == "$HOST_SAVE_DEFAULT" ]]; then
    DEFAULT_OLD_IDX=$((i + 1))
    break
  fi
done
# New = first that isn't the host default
for i in "${!PLAYER_SAVS[@]}"; do
  if [[ "${PLAYER_SAVS[$i]}" != "$HOST_SAVE_DEFAULT" ]]; then
    DEFAULT_NEW_IDX=$((i + 1))
    break
  fi
done

echo ""
echo "World: $WORLD_FOLDER"
echo "Player save files:"
for i in "${!PLAYER_SAVS[@]}"; do
  echo "  $((i+1))) ${PLAYER_SAVS[$i]}.sav"
done
echo ""

# Which save is the host's ORIGINAL (co-op) character to fix? Default = 000...001
read -r -p "Which save is the host's ORIGINAL character to fix? [${DEFAULT_OLD_IDX}]: " choice_old
choice_old="${choice_old:-$DEFAULT_OLD_IDX}"
if [[ ! "$choice_old" =~ ^[0-9]+$ ]] || [[ "$choice_old" -lt 1 ]] || [[ "$choice_old" -gt ${#PLAYER_SAVS[@]} ]]; then
  log_err "Invalid selection. Enter 1-${#PLAYER_SAVS[@]}."
  exit 1
fi
OLD_GUID="${PLAYER_SAVS[$((choice_old-1))]}"

# Which save is the host's NEW (dedicated server) character to overwrite? Default = first other
read -r -p "Which save is the host's NEW character (will be overwritten with fixed data)? [${DEFAULT_NEW_IDX}]: " choice_new
choice_new="${choice_new:-$DEFAULT_NEW_IDX}"
if [[ ! "$choice_new" =~ ^[0-9]+$ ]] || [[ "$choice_new" -lt 1 ]] || [[ "$choice_new" -gt ${#PLAYER_SAVS[@]} ]]; then
  log_err "Invalid selection. Enter 1-${#PLAYER_SAVS[@]}."
  exit 1
fi
NEW_GUID="${PLAYER_SAVS[$((choice_new-1))]}"

if [[ "$OLD_GUID" == "$NEW_GUID" ]]; then
  log_err "Old and new must be different."
  exit 1
fi

OLD_SAV="$PLAYERS_DIR/${OLD_GUID}.sav"
NEW_SAV="$PLAYERS_DIR/${NEW_GUID}.sav"

if [[ ! -f "$OLD_SAV" ]]; then
  log_err "Not found: $OLD_SAV"
  exit 1
fi
if [[ ! -f "$NEW_SAV" ]]; then
  log_err "Not found: $NEW_SAV. Host must create a new character on the server first."
  exit 1
fi

echo ""
echo "This will: patch $OLD_GUID.sav and Level.sav to use $NEW_GUID, then rename the patched file to $NEW_GUID.sav. A backup will be created."
read -r -p "Continue? [y/N]: " confirm
if [[ ! "${confirm:-n}" =~ ^[Yy] ]]; then
  log "Aborted."
  exit 0
fi

log "Stopping palworld service..."
systemctl stop palworld.service 2>/dev/null || true

BACKUP_NAME="${WORLD_FOLDER}.bak-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$SAVE_BASE/$BACKUP_NAME"
log "Backing up world to $BACKUP_PATH"
cp -a "$WORLD_PATH" "$BACKUP_PATH"
chown -R steam:steam "$BACKUP_PATH"

# Patch .sav files using Python stdlib only: decompress (palsav-style header + zlib), replace GUID string, recompress.
# Formatted GUID = 36-char hyphenated lowercase; same length so safe to replace in raw decompressed GVAS bytes.
format_guid() {
  local g="$1"
  echo "${g:0:8}-${g:8:4}-${g:12:4}-${g:16:4}-${g:20:12}" | tr '[:upper:]' '[:lower:]'
}

OLD_FMT="$(format_guid "$OLD_GUID")"
NEW_FMT="$(format_guid "$NEW_GUID")"

log "Patching save files (replace host GUID in player save and Level.sav)..."
python3 - "$WORLD_PATH" "$OLD_SAV" "$NEW_SAV" "$OLD_FMT" "$NEW_FMT" <<'PYTHON_SCRIPT'
import sys
import zlib

MAGIC = b"PlZ"

def decompress_sav(data: bytes):
    if len(data) < 12:
        raise SystemExit("Save file too short")
    uncompressed_len = int.from_bytes(data[0:4], "little")
    compressed_len = int.from_bytes(data[4:8], "little")
    magic = data[8:11]
    save_type = data[11]
    start = 12
    if magic == b"CNK":
        if len(data) < 24:
            raise SystemExit("Save file too short (CNK)")
        uncompressed_len = int.from_bytes(data[12:16], "little")
        compressed_len = int.from_bytes(data[16:20], "little")
        magic = data[20:23]
        save_type = data[23]
        start = 24
    if magic != MAGIC:
        raise SystemExit("Not a Palworld compressed save (bad magic)")
    if save_type not in (0x31, 0x32):
        raise SystemExit("Unhandled save type")
    payload = data[start:]
    if save_type == 0x31:
        raw = zlib.decompress(payload)
    else:
        raw = zlib.decompress(zlib.decompress(payload))
    if len(raw) != uncompressed_len:
        raise SystemExit("Uncompressed length mismatch")
    return raw, save_type

def compress_sav(raw: bytes, save_type: int) -> bytes:
    inner = zlib.compress(raw)
    compressed_len = len(inner)
    if save_type == 0x32:
        compressed = zlib.compress(inner)
    else:
        compressed = inner
    out = bytearray()
    out.extend(len(raw).to_bytes(4, "little"))
    out.extend(compressed_len.to_bytes(4, "little"))
    out.extend(MAGIC)
    out.append(save_type)
    out.extend(compressed)
    return bytes(out)

def patch_file(path: str, old_fmt: str, new_fmt: str) -> None:
    old_b = old_fmt.encode("utf-8")
    new_b = new_fmt.encode("utf-8")
    if len(old_b) != len(new_b):
        raise SystemExit("GUID length mismatch")
    with open(path, "rb") as f:
        data = f.read()
    raw, save_type = decompress_sav(data)
    if old_b not in raw:
        raise SystemExit(f"GUID string not found in {path} (format may differ)")
    raw = raw.replace(old_b, new_b)
    out = compress_sav(raw, save_type)
    with open(path, "wb") as f:
        f.write(out)

def main():
    world_path, old_sav, new_sav, old_fmt, new_fmt = sys.argv[1:6]
    level_sav = world_path + "/Level.sav"
    patch_file(level_sav, old_fmt, new_fmt)
    patch_file(old_sav, old_fmt, new_fmt)
    import os
    os.remove(new_sav)
    os.rename(old_sav, new_sav)

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

chown -R steam:steam "$WORLD_PATH"
log "Starting palworld service..."
systemctl start palworld.service

log "Done. Host save patched and renamed to $NEW_GUID.sav; Level.sav updated. Backup: $BACKUP_PATH"
