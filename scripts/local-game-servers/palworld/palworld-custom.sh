#!/bin/bash
# palworld-custom.sh — Install Palworld server then run full config wizard BEFORE first start.
# Configuration is applied at setup time so the world is never created with wrong settings (e.g. hardcore).
# Same install steps as palworld.sh; then runs config-palworld.sh (advanced mode) and does not start the server until config is done.
# Usage: sudo ./palworld-custom.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PALWORLD_CUSTOM=1
exec "$SCRIPT_DIR/palworld.sh" "$@"
