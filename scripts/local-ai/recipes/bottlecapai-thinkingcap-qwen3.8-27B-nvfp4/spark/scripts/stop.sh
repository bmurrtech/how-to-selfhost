#!/usr/bin/env bash
# stop.sh — stop/remove the recipe container via compose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./recipe_bootstrap_local.sh
source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"

if [[ -f "$RUNTIME_ENV" ]]; then
	compose down --remove-orphans || true
fi
docker rm -f "$NAME" >/dev/null 2>&1 || true
echo "Stopped $NAME"
