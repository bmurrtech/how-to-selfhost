#!/usr/bin/env bash
# config.sh — ensure .env + interactive profile (unified RTX).
#   just config         — mutate + show
#   just config --show  — resolved knobs only (no prompts / no writes)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"

rtx_prefer_volume_cache
mode="$(rtx_detect_exec_mode)"

SHOW_ONLY=0
case "${1:-}" in
--show | show)
	SHOW_ONLY=1
	shift || true
	;;
esac

if [[ "$SHOW_ONLY" -eq 1 ]]; then
	if [[ -f "$RUNTIME_ENV" ]]; then
		# shellcheck disable=SC1090
		set -a
		# shellcheck source=/dev/null
		source "$RUNTIME_ENV"
		set +a
	fi
	ops_config_show "$RUNTIME_ENV" "$mode"
	exit 0
fi

config_env_ensure

detected="$(rtx_gpu_count)"
export RTX_INTERACTIVE="${RTX_INTERACTIVE:-1}"
count="$(rtx_interactive_select "$RECIPE_DIR" "$detected")"
echo "GPUs selected: ${count}"

rtx_resolve_write "$RUNTIME_ENV"
echo
config_env_summary "$mode"
echo
ops_config_show "$RUNTIME_ENV" "$mode"
echo
echo "just token"
echo "Force mode: EXEC_MODE=docker|native"
echo "Non-interactive: RTX_INTERACTIVE=0 PROFILE_CONFIRM=1"
echo "Show only: just config --show"
