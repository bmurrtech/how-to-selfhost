#!/usr/bin/env bash
# doctor.sh — alias for check (deployment sanity).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/check.sh" "$@"
