#!/bin/bash
# palworld-hard.sh — Install Palworld server with Hard difficulty preset (harder rates, more penalty).
# Same as palworld.sh but applies Hard preset; still prompts for Admin password and REST API.
# Usage: sudo ./palworld-hard.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PALWORLD_PRESET=hard
exec "$SCRIPT_DIR/palworld.sh" "$@"
