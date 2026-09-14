#!/usr/bin/env bash
# logs.sh — follow or tail container logs (no secret echo beyond docker's own output).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap

TAIL="${1:-100}"
if [[ "${FOLLOW:-0}" == "1" || "${1:-}" == "-f" ]]; then
	docker logs -f "$NAME"
else
	docker logs --tail "$TAIL" "$NAME"
fi
