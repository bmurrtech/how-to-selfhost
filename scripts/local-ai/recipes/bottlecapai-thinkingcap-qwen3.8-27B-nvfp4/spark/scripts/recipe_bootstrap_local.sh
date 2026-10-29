#!/usr/bin/env bash
# recipe_bootstrap_local.sh — paths + env for bottlecap ThinkingCap NVFP4 / spark.
# shellcheck shell=bash
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=./recipe_bootstrap_local.sh
#   source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"

# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-bottlecap-thinkingcap-spark}"
export SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-ThinkingCap-Qwen3.8-27B}"
export MODEL="${MODEL:-bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4}"
export VLLM_MODEL="$MODEL"
export IMAGE="${IMAGE:-ghcr.io/styles01/qwen38-mtp3:latest}"
# Download helper image must provide `hf` CLI (serve IMAGE often does not).
export VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:v0.27.1}"
export NAME="${NAME:-thinkingcap-qwen38-27b-nvfp4}"
export CONTAINER_NAME="$NAME"

require_hf_token() {
	if declare -F local_ai_resolve_hf_token >/dev/null 2>&1; then
		local_ai_resolve_hf_token
	fi
	if [[ -n "${HF_TOKEN:-}" ]]; then
		return 0
	fi
	echo "FAILED: Hugging Face token required for gated model ${MODEL}." >&2
	echo "Set HF_TOKEN, HUGGING_FACE_HUB_TOKEN, or RUNPOD_SECRET_HF_TOKEN in the environment" >&2
	echo "or in scripts/local-ai/.env before just setup / just doctor." >&2
	return 1
}

print_model_banner() {
	echo "ThinkingCap NVFP4 (gated) — PolyForm Small Business + personal-use grant; accept HF terms first."
}

pull_image_with_retries() {
	local max_attempts="${PULL_RETRIES:-3}" attempt rc=1
	for attempt in $(seq 1 "$max_attempts"); do
		echo "--- docker pull $IMAGE (attempt $attempt/$max_attempts) ---"
		if docker pull "$IMAGE"; then
			pacman_progress_done "image pulled"
			return 0
		fi
		echo "FAILED: docker pull $IMAGE (attempt $attempt/$max_attempts) — retrying…" >&2
		sleep $((attempt * 5))
	done
	echo "FAILED: docker pull $IMAGE after $max_attempts attempts" >&2
	return 1
}

stop_conflicting_port8000() {
	local other="qwen38-nvfp4"
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$other"; then
		echo "Stopping conflicting flash-next container $other (port ${PORT} is exclusive)…"
		docker rm -f "$other" >/dev/null 2>&1 || true
	fi
}
