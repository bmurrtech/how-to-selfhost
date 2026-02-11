#!/bin/bash
# palworld-save-import.sh — Import Palworld world save from a public URL (zip).
# Run on the game server (SSH or Proxmox console). Requires sudo.
# Usage: sudo PAL_INSTALL_DIR=/home/steam/palserver ./palworld-save-import.sh [URL]
# If URL is omitted and stdin is a TTY, prompts for URL. Do not upload WorldOption.sav in the zip.

set -euo pipefail

PAL_INSTALL_DIR="${PAL_INSTALL_DIR:-/home/steam/palserver}"
SAVE_BASE="$PAL_INSTALL_DIR/Pal/Saved/SaveGames/0"
CONFIG_DIR="$PAL_INSTALL_DIR/Pal/Saved/Config/LinuxServer"
TMP_ZIP="/tmp/palworld-import.zip"
TMP_EXTRACT="/tmp/palworld-import-extract"
IMPORT_OK=false

recovery_message() {
  echo ""
  echo "=== Import failed: recovery ==="
  echo "Restart the server manually: sudo systemctl start palworld"
  echo "Or fix the issue and re-run this script to complete import and restart."
  echo "=== ==="
}

cleanup_and_exit() {
  rm -rf "$TMP_EXTRACT"
  rm -f "$TMP_ZIP"
  if [[ "$IMPORT_OK" != true ]]; then
    recovery_message
    exit 1
  fi
  exit 0
}

trap cleanup_and_exit EXIT

if [[ $# -lt 1 ]]; then
  if [[ -t 0 ]]; then
    echo "URL of zip containing world save (or press Enter to show usage):"
    read -r URL
    if [[ -z "${URL:-}" ]]; then
      echo "Usage: $0 <URL of zip containing world save>"
      echo "Example: $0 https://storage.googleapis.com/your-bucket/palworld-world.zip"
      exit 1
    fi
  else
    echo "Usage: $0 <URL of zip containing world save>"
    echo "Example: $0 https://storage.googleapis.com/your-bucket/palworld-world.zip"
    exit 1
  fi
else
  URL="$1"
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root (sudo) to stop/start the service and set ownership."
  exit 1
fi

if [[ ! -d "$SAVE_BASE" ]]; then
  echo "Save directory not found: $SAVE_BASE"
  echo "Ensure Palworld server has been run at least once (e.g. via palworld.sh setup)."
  exit 1
fi

echo "Stopping palworld service..."
systemctl stop palworld.service || true

echo "Downloading from URL..."
rm -f "$TMP_ZIP"
wget -O "$TMP_ZIP" -- "$URL"

echo "Extracting..."
rm -rf "$TMP_EXTRACT"
mkdir -p "$TMP_EXTRACT"
unzip -o -q "$TMP_ZIP" -d "$TMP_EXTRACT"

# Remove WorldOption.sav if present (can override server config)
find "$TMP_EXTRACT" -name "WorldOption.sav" -delete

# Detect structure: one top-level folder vs flat files
COUNT_DIRS=0
FIRST_DIR=""
for d in "$TMP_EXTRACT"/*/; do
  if [[ -d "$d" ]]; then
    ((COUNT_DIRS++)) || true
    [[ -z "$FIRST_DIR" ]] && FIRST_DIR="$d"
  fi
done
if [[ $COUNT_DIRS -eq 1 ]] && [[ -n "$FIRST_DIR" ]]; then
  # Single top-level directory (e.g. zip contains "458AD072.../Level.sav")
  SRC_DIR="$FIRST_DIR"
  FOLDER_NAME="$(basename "$SRC_DIR")"
else
  # Flat: zip contains Level.sav, LevelMeta.sav, Players/ at top level
  SRC_DIR="$TMP_EXTRACT"
  FOLDER_NAME="imported-$(date +%Y%m%d-%H%M%S)"
fi

# Backup existing folder if present (use first existing folder under SAVE_BASE)
EXISTING="$(find "$SAVE_BASE" -maxdepth 1 -type d ! -path "$SAVE_BASE" | head -1)"
if [[ -n "$EXISTING" ]]; then
  BACKUP_NAME="$(basename "$EXISTING").bak-$(date +%Y%m%d-%H%M%S)"
  echo "Backing up existing save to $SAVE_BASE/$BACKUP_NAME"
  mv "$EXISTING" "$SAVE_BASE/$BACKUP_NAME"
fi

TARGET_DIR="$SAVE_BASE/$FOLDER_NAME"
mkdir -p "$TARGET_DIR"
echo "Copying save data to $TARGET_DIR"
cp -a "$SRC_DIR"/* "$TARGET_DIR"/
chown -R steam:steam "$TARGET_DIR"

# Update DedicatedServerName so server loads this world
for CONFIG_FILE in "$CONFIG_DIR/GameUserSettings.ini" "$CONFIG_DIR/PalWorldSettings.ini"; do
  if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q '^DedicatedServerName=' "$CONFIG_FILE" 2>/dev/null; then
      sed -i "s/^DedicatedServerName=.*/DedicatedServerName=$FOLDER_NAME/" "$CONFIG_FILE"
      echo "Updated DedicatedServerName to $FOLDER_NAME in $(basename "$CONFIG_FILE")"
    else
      echo "DedicatedServerName=$FOLDER_NAME" >> "$CONFIG_FILE"
    fi
    chown steam:steam "$CONFIG_FILE"
    break
  fi
done

IMPORT_OK=true
echo "Starting palworld service..."
systemctl start palworld.service
echo "Import complete. World '$FOLDER_NAME' is set as the active save. Server starting."
