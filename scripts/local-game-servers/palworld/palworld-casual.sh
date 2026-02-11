#!/bin/bash
# palworld-casual.sh — Install Palworld server with Casual difficulty preset (easier rates, less penalty).
# Same as palworld.sh but applies Casual preset; still prompts for Admin password and REST API.
# Usage: sudo ./palworld-casual.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PALWORLD_PRESET=casual
exec "$SCRIPT_DIR/palworld.sh" "$@"
