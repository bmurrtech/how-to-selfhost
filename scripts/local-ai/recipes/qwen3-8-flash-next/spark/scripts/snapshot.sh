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

EXEC_MODE=docker
export EXEC_MODE
ops_snapshot_run
