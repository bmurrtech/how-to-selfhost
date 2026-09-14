#!/usr/bin/env bash
# config.sh — print resolved serve config (no secrets).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Resolve without requiring API key for display; strip secrets from output.
if [[ -z "${VLLM_API_KEY:-}" ]]; then
	VLLM_API_KEY="__redacted__"
	export VLLM_API_KEY
fi
resolve_serve_write "$tmp" >/dev/null

echo "Resolved config (${RECIPE_DIR}):"
grep -E '^(IMAGE|NAME|PORT|HF_CACHE|SNAP_IN|CTX|SEQS|GPU_MEM|MTP|PREFIX_CACHE|YARN|KV_DTYPE|MODE|RESOLVED_BASE|SERVED_MODEL_NAME|CONFIG_HASH|SPLIT_OPS|MAX_NUM_BATCHED_TOKENS|SHM_SIZE)=' "$tmp" |
	sed 's/^VLLM_API_KEY=.*/VLLM_API_KEY=(set)/' || true

if [[ -f "$RUNTIME_ENV" ]]; then
	echo
	echo "Active .runtime.env CONFIG_HASH=$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | cut -d= -f2- | cut -c1-12)…"
fi
