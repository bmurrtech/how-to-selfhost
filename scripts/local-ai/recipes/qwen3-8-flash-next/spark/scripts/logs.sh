#!/usr/bin/env bash
# logs.sh — container logs (+ error/cuda/oom/vllm filters).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"
# shellcheck source=../../../../scripts/lib/ops_logs.sh
source "${LIB_DIR}/ops_logs.sh"

arg="${1:-100}"
ops_logs_run docker "$NAME" "$arg"
