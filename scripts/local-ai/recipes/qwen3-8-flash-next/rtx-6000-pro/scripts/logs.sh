#!/usr/bin/env bash
# logs.sh — docker or native vllm log (+ error/cuda/oom/vllm filters).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"
# shellcheck source=../../../../scripts/lib/ops_logs.sh
source "${LIB_DIR}/ops_logs.sh"

mode="$(rtx_detect_exec_mode)"
arg="${1:-100}"

if [[ "$mode" == "docker" ]]; then
	ops_logs_run docker "$NAME" "$arg"
else
	ops_logs_run native "${RECIPE_DIR}/.run/vllm.log" "$arg"
fi
