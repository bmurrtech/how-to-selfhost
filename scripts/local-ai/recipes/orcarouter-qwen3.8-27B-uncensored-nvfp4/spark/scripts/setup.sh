#!/usr/bin/env bash
# setup.sh — HF weights + pull serve image (idempotent; no blazux build).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./recipe_bootstrap_local.sh
source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"

echo "=== setup: orcarouter-qwen3.8-27B-uncensored-nvfp4 / spark ==="

mkdir -p "$HF_CACHE" "${HOME}/models"
CONFIG_PROMPT_HF_TOKEN=0
export CONFIG_PROMPT_HF_TOKEN
config_env_ensure
unset CONFIG_PROMPT_HF_TOKEN

if ! require_hf_token; then
	exit 1
fi

echo "--- weights ---"
if [[ "${FORCE_DOWNLOAD:-0}" != "1" ]] && weights_complete; then
	pacman_progress_done "skip download (weights present)"
else
	if run_download && weights_complete; then
		pacman_progress_done "weights ready"
	else
		echo "FAILED: weights incomplete after retries — check HF token and network" >&2
		exit 1
	fi
fi

echo "--- image $IMAGE ---"
if docker image inspect "$IMAGE" >/dev/null 2>&1 && [[ "${FORCE_PULL:-0}" != "1" ]]; then
	echo "skip: image $IMAGE present"
else
	if ! pull_image_with_retries; then
		exit 1
	fi
fi

echo
echo "setup complete."
echo "Next: just deploy"
