#!/usr/bin/env bash
# snapshot.sh — one shareable redacted diagnostic bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"
# shellcheck source=../../../../scripts/lib/ops_snapshot.sh
source "${LIB_DIR}/ops_snapshot.sh"
if [[ -f "${LIB_DIR}/rtx_serve.sh" ]]; then
	# shellcheck source=../../../../scripts/lib/rtx_serve.sh
	source "${LIB_DIR}/rtx_serve.sh"
	if declare -F rtx_prefer_volume_cache >/dev/null 2>&1; then
		rtx_prefer_volume_cache
	fi
	if declare -F rtx_detect_exec_mode >/dev/null 2>&1; then
		EXEC_MODE="$(rtx_detect_exec_mode)"
		export EXEC_MODE
	fi
fi

ops_snapshot_run
