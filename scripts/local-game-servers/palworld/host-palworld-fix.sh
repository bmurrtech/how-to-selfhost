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
DEBUG_LOG="${HOST_PALWORLD_FIX_DEBUG_LOG:-}"
python3 - "$WORLD_PATH" "$OLD_SAV" "$NEW_SAV" "$OLD_FMT" "$NEW_FMT" "$DEBUG_LOG" <<'PYTHON_SCRIPT'
import sys
import zlib
import json
import time

# Level.sav uses b'PlM' (0x50 0x6c 0x4d); player saves use b'PlZ' (0x50 0x6c 0x5a). Match full 3-byte sequence.
VALID_MAGICS = {b"PlZ", b"PlM"}

def _err(path: str, msg: str, detail: str = "") -> None:
    out = f"{path}: {msg}"
    if detail:
        out += f" {detail}"
    print(f"[ERROR] {out}", file=sys.stderr, flush=True)
    sys.exit(1)

def _debug_log(debug_path: str, location: str, message: str, data: dict, hypothesis_id: str = "") -> None:
    if not debug_path:
        return
    line = f"[DEBUG] {location}: {message} :: {data}"
    if hypothesis_id:
        line += f" (hypothesisId={hypothesis_id})"
    if debug_path == "stdout":
        print(line, flush=True)
    else:
        payload = {"id": f"log_{int(time.time()*1000)}", "timestamp": int(time.time() * 1000), "location": location, "message": message, "data": data}
        if hypothesis_id:
            payload["hypothesisId"] = hypothesis_id
        try:
            with open(debug_path, "a") as f:
                f.write(json.dumps(payload) + "\n")
        except Exception:
            pass

def decompress_sav(data: bytes, path: str = "", debug_path: str = "") -> tuple:
    if len(data) < 12:
        _err(path, "Save file too short.", f"(size={len(data)}, need at least 12 bytes)")
    # Resolve header layout before validating magic. Bytes 8:11 can be b'CNK' (then magic at 20:23) or the actual magic (PlZ/PlM at 8:11).
    bytes_8_11 = data[8:11]
    if bytes_8_11 == b"CNK":
        layout = "CNK"
        if len(data) < 24:
            _err(path, "Save file too short for CNK header.", f"(size={len(data)}, need 24)")
        uncompressed_len = int.from_bytes(data[12:16], "little")
        compressed_len = int.from_bytes(data[16:20], "little")
        magic = data[20:23]
        save_type = data[23]
        start = 24
        magic_offset = "20:23"
    else:
        layout = "standard"
        uncompressed_len = int.from_bytes(data[0:4], "little")
        compressed_len = int.from_bytes(data[4:8], "little")
        magic = bytes_8_11
        save_type = data[11]
        start = 12
        magic_offset = "8:11"
    if magic == b"\x00\x00\x00" and uncompressed_len == 0 and compressed_len == 0:
        _err(path, "Header is all nulls; file may be empty or corrupted.", "(not a compressed Palworld save)")
    if magic not in VALID_MAGICS:
        _err(
            path,
            "Unsupported magic.",
            f"Layout={layout}, validated magic at offset {magic_offset} = {magic!r} (hex: {magic.hex()}); expected one of {VALID_MAGICS}. file size = {len(data)}. First 32 bytes (hex): {data[:32].hex()}"
        )
    if save_type not in (0x31, 0x32):
        _err(path, "Unhandled save type byte.", f"Layout={layout}. Expected 0x31 or 0x32, got 0x{save_type:02x}. First 32 bytes (hex): {data[:32].hex()}")
    if compressed_len <= 0 or compressed_len > len(data):
        _err(path, "Invalid compressed_len from header.", f"Layout={layout}. compressed_len={compressed_len} file_size={len(data)}. Header may be wrong layout.")
    # For 0x31 the payload is exactly compressed_len bytes; for 0x32 the rest of the file is the outer stream.
    if save_type == 0x31:
        if len(data) < start + compressed_len:
            _err(path, "File too short for payload.", f"Layout={layout}. Need start+compressed_len={start + compressed_len}, have {len(data)}.")
        payload = data[start:start + compressed_len]
    else:
        payload = data[start:]
    header = data[:start]
    _debug_log(debug_path, "decompress_sav:after_layout", "Layout and payload slice", {
        "path": path, "layout": layout, "start": start, "save_type": save_type,
        "compressed_len": compressed_len, "uncompressed_len": uncompressed_len,
        "first_8_payload_hex": payload[:8].hex(), "is_level_sav": "Level.sav" in path
    }, "H1")
    if debug_path:
        print("Header bytes (first 32):", data[:32].hex(), flush=True)
        print("Layout:", layout, "Start:", start, "Compressed len:", compressed_len, "Save type:", hex(save_type), flush=True)
        print("Payload first 4:", payload[:4].hex(), flush=True)
    try:
        if save_type == 0x31:
            raw = zlib.decompress(payload)
        else:
            raw = zlib.decompress(zlib.decompress(payload))
    except zlib.error as e:
        _debug_log(debug_path, "decompress_sav:zlib_error", "Zlib decompress failed", {
            "path": path, "layout": layout, "start": start,
            "first_8_payload_hex": payload[:8].hex(), "error": str(e)
        }, "H5")
        _err(
            path,
            "Zlib decompress failed; data may be corrupted or payload offset wrong.",
            f"Layout={layout}. {e}. uncompressed_len={uncompressed_len} compressed_len={compressed_len} start={start}. First 8 payload bytes (hex): {payload[:8].hex()} (valid zlib often starts 78 9c or 78 da)."
        )
    if len(raw) != uncompressed_len:
        _err(path, "Uncompressed length mismatch.", f"Expected {uncompressed_len}, got {len(raw)}")
    return raw, save_type, magic, header, layout

def compress_sav(raw: bytes, save_type: int, magic: bytes, header: bytes, layout: str) -> bytes:
    if len(magic) != 3:
        print(f"[ERROR] compress_sav: magic must be 3 bytes, got {len(magic)}", file=sys.stderr, flush=True)
        sys.exit(1)
    inner = zlib.compress(raw)
    compressed_len = len(inner)
    if save_type == 0x32:
        compressed = zlib.compress(inner)
    else:
        compressed = inner
    out = bytearray(header)
    if layout == "standard":
        out[0:4] = len(raw).to_bytes(4, "little")
        out[4:8] = compressed_len.to_bytes(4, "little")
    else:
        out[12:16] = len(raw).to_bytes(4, "little")
        out[16:20] = compressed_len.to_bytes(4, "little")
    out.extend(compressed)
    return bytes(out)

def patch_file(path: str, old_fmt: str, new_fmt: str, debug_path: str = "") -> None:
    old_b = old_fmt.encode("utf-8")
    new_b = new_fmt.encode("utf-8")
    if len(old_b) != len(new_b):
        _err(path, "GUID length mismatch.", "")
    with open(path, "rb") as f:
        data = f.read()
    raw, save_type, magic, header, layout = decompress_sav(data, path, debug_path)
    if old_b not in raw:
        print(f"[ERROR] {path}: GUID string {old_fmt!r} not found in decompressed data (save format may differ or file may be from another source).", file=sys.stderr, flush=True)
        sys.exit(1)
    raw = raw.replace(old_b, new_b)
    out = compress_sav(raw, save_type, magic, header, layout)
    with open(path, "wb") as f:
        f.write(out)

def main():
    world_path, old_sav, new_sav, old_fmt, new_fmt = sys.argv[1:6]
    debug_path = (sys.argv[6] if len(sys.argv) > 6 else "") or ""
    level_sav = world_path + "/Level.sav"
    patch_file(level_sav, old_fmt, new_fmt, debug_path)
    patch_file(old_sav, old_fmt, new_fmt, debug_path)
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
