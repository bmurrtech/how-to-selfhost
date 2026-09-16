#!/usr/bin/env bash
# gpu.sh — live GPU evidence (nvidia-smi).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_gpu.sh
source "${LIB_DIR}/ops_gpu.sh"

case "${1:-}" in
--watch | -w | watch)
	ops_gpu_watch "${2:-2}"
	;;
*)
	ops_gpu_show
	;;
esac
