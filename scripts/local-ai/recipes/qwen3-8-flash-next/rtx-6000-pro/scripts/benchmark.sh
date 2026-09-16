#!/usr/bin/env bash
# benchmark.sh — wrap vllm bench serve (fixed default workload).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_bench.sh
source "${LIB_DIR}/ops_bench.sh"
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"

require_api_key
ops_bench_defaults
ops_bench_parse_args "$@" || exit $?
ops_bench_ensure_model_name
ops_bench_health

REPORT_TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="${BENCH_DIR}/bench-serve-${REPORT_TS}.txt"
ops_bench_execute "$REPORT_FILE"
