#!/bin/bash
# palworld-save-export.sh — Backup Palworld world save (local zip + optional rclone to cloud).
# Run on the game server via SSH or Proxmox console. Requires sudo.
# Set PALWORLD_BACKUP_REMOTE (e.g. minio:palworld-backups) to upload after backup.
# Usage: sudo PALWORLD_BACKUP_REMOTE=minio:palworld-backups ./palworld-save-export.sh

set -euo pipefail

PAL_INSTALL_DIR="${PAL_INSTALL_DIR:-/home/steam/palserver}"
SAVE_BASE="$PAL_INSTALL_DIR/Pal/Saved/SaveGames/0"
CONFIG_DIR="$PAL_INSTALL_DIR/Pal/Saved/Config/LinuxServer"
LOCAL_BACKUP_DIR="${PALWORLD_BACKUP_DIR:-/home/steam/palserver-backups}"
EXPORT_OK=false

recovery_message() {
  echo ""
  echo "=== Backup failed: recovery ==="
  echo "Restart the server manually: sudo systemctl start palworld"
  echo "Or fix the issue and re-run this script to complete backup and restart."
  echo "=== ==="
}

cleanup_and_exit() {
  if [[ "$EXPORT_OK" != true ]]; then
    recovery_message
    exit 1
  fi
  exit 0
}

trap cleanup_and_exit EXIT

if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root (sudo) to stop/start the service and read save files."
  exit 1
fi

if [[ ! -d "$SAVE_BASE" ]]; then
  echo "Save directory not found: $SAVE_BASE"
  exit 1
fi

# Detect active save folder: DedicatedServerName from config, or single folder under SaveGames/0
SAVE_FOLDER=""
for CONFIG_FILE in "$CONFIG_DIR/GameUserSettings.ini" "$CONFIG_DIR/PalWorldSettings.ini"; do
  if [[ -f "$CONFIG_FILE" ]] && grep -q '^DedicatedServerName=' "$CONFIG_FILE" 2>/dev/null; then
    SAVE_FOLDER="$(grep '^DedicatedServerName=' "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')"
    break
  fi
done
if [[ -z "$SAVE_FOLDER" ]] || [[ ! -d "$SAVE_BASE/$SAVE_FOLDER" ]]; then
  # Fallback: single folder under SaveGames/0
  SINGLE="$(find "$SAVE_BASE" -maxdepth 1 -type d ! -path "$SAVE_BASE" | head -1)"
  if [[ -n "$SINGLE" ]]; then
    SAVE_FOLDER="$(basename "$SINGLE")"
  else
    echo "No save folder found under $SAVE_BASE"
    exit 1
  fi
fi

SAVE_DIR="$SAVE_BASE/$SAVE_FOLDER"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BAK_DIR="${SAVE_DIR}.bak-${TIMESTAMP}"
ZIP_NAME="palworld-save-${SAVE_FOLDER}-${TIMESTAMP}.zip"
TMP_ZIP="/tmp/$ZIP_NAME"

echo "Stopping palworld service..."
systemctl stop palworld.service || true

echo "Creating local backup copy..."
cp -a "$SAVE_DIR" "$BAK_DIR"
chown -R steam:steam "$BAK_DIR"

echo "Zipping backup (working on copy to avoid touching live save)..."
rm -f "$TMP_ZIP"
cd "$SAVE_BASE"
zip -r -q "$TMP_ZIP" "$(basename "$BAK_DIR")"
cd - >/dev/null

# Remove the .bak copy; we only keep the zip
rm -rf "$BAK_DIR"

echo "Starting palworld service..."
systemctl start palworld.service

# Move zip to local backup dir if writable
mkdir -p "$LOCAL_BACKUP_DIR"
chown steam:steam "$LOCAL_BACKUP_DIR" 2>/dev/null || true
if cp "$TMP_ZIP" "$LOCAL_BACKUP_DIR/$ZIP_NAME" 2>/dev/null; then
  chown steam:steam "$LOCAL_BACKUP_DIR/$ZIP_NAME"
  echo "Local backup: $LOCAL_BACKUP_DIR/$ZIP_NAME"
else
  echo "Local copy to $LOCAL_BACKUP_DIR failed; zip is at $TMP_ZIP"
fi

if [[ -n "${PALWORLD_BACKUP_REMOTE:-}" ]]; then
  echo "Uploading to $PALWORLD_BACKUP_REMOTE ..."
  if command -v rclone >/dev/null 2>&1; then
    if rclone copy "$TMP_ZIP" "$PALWORLD_BACKUP_REMOTE/"; then
      echo "Uploaded to $PALWORLD_BACKUP_REMOTE/$ZIP_NAME"
    else
      echo "rclone upload failed. Local backup is at $LOCAL_BACKUP_DIR/$ZIP_NAME (or $TMP_ZIP)."
      EXPORT_OK=true
      exit 0
    fi
  else
    echo "rclone not found. Install rclone and configure remote. Local backup only: $LOCAL_BACKUP_DIR/$ZIP_NAME"
  fi
else
  echo "PALWORLD_BACKUP_REMOTE not set; skipping cloud upload. See guides/how-to_s3-minio.md to configure."
fi

rm -f "$TMP_ZIP"
EXPORT_OK=true
