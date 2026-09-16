#!/usr/bin/env bash
# probe.sh — minimal end-to-end health test (one completion).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"
# shellcheck source=../../../../scripts/lib/ops_probe.sh
source "${LIB_DIR}/ops_probe.sh"

require_api_key
ops_probe_run
