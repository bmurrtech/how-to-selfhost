#!/bin/bash
# palworld-normal.sh — Install Palworld server with Normal difficulty preset (balanced defaults).
# Same as palworld.sh but applies Normal preset; still prompts for Admin password and REST API.
# Usage: sudo ./palworld-normal.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PALWORLD_PRESET=normal
exec "$SCRIPT_DIR/palworld.sh" "$@"
