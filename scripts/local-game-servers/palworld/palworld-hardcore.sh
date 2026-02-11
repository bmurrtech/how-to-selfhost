#!/bin/bash
# palworld-hardcore.sh — Install Palworld server with Hardcore preset (all hardcore features enabled by default).
# No respawn on death, permanent Pal loss, etc. Still prompts for Admin password and REST API.
# Usage: sudo ./palworld-hardcore.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PALWORLD_PRESET=hardcore
exec "$SCRIPT_DIR/palworld.sh" "$@"
