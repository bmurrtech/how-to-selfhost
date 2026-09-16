#!/usr/bin/env bash
# benchmark-load.sh — vllm bench serve at a few request rates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_bench.sh
source "${LIB_DIR}/ops_bench.sh"
if [[ -f "${LIB_DIR}/rtx_serve.sh" ]]; then
	# shellcheck source=../../../../scripts/lib/rtx_serve.sh
	source "${LIB_DIR}/rtx_serve.sh"
fi

require_api_key
ops_bench_defaults
ops_bench_parse_args "$@" || exit $?
ops_bench_ensure_model_name
ops_bench_health
ops_bench_load_run
