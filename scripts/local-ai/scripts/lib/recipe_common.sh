#!/usr/bin/env bash
# recipe_common.sh — path + env bootstrap for recipe scripts.
# shellcheck shell=bash
#
# Usage (from recipes/.../scripts/*.sh):
#   SCRIPT_DIR=...
#   # shellcheck source=../../../scripts/lib/recipe_common.sh
#   source "${SCRIPT_DIR}/../../../scripts/lib/recipe_common.sh"
#   recipe_bootstrap

recipe_bootstrap() {
	# Prefer SCRIPT_DIR set by the calling recipe script (Justfile path).
	if [[ -z "${SCRIPT_DIR:-}" ]]; then
		local caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
		SCRIPT_DIR="$(cd "$(dirname "$caller")" && pwd)"
	fi
	RECIPE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
	ROOT_DIR="$(cd "${RECIPE_DIR}/../../.." && pwd)"
	LIB_DIR="${ROOT_DIR}/scripts/lib"
	RUNTIME_ENV="${RECIPE_DIR}/.runtime.env"
	COMPOSE_FILE="${RECIPE_DIR}/compose.yaml"

	# shellcheck source=./load_env.sh
	source "${LIB_DIR}/load_env.sh"
	# shellcheck source=./config_env.sh
	source "${LIB_DIR}/config_env.sh"
	# shellcheck source=./pacman_progress.sh
	source "${LIB_DIR}/pacman_progress.sh"
	# shellcheck source=./weights.sh
	source "${LIB_DIR}/weights.sh"
	# shellcheck source=./resolve_serve.sh
	source "${LIB_DIR}/resolve_serve.sh"

	local_ai_load_env "$RECIPE_DIR"

	# Canonical knobs (serve.env / .env / shell may already set)
	export MODEL="${MODEL:-${VLLM_MODEL:-nvidia/Qwen3.8-Flash-Next-NVFP4}}"
	export VLLM_MODEL="$MODEL"
	export SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-flash-next}"
	export HF_CACHE="${HF_CACHE:-${HOME}/.cache/huggingface}"
	export IMAGE="${IMAGE:-qwen38-flash-dgx:c578815}"
	export NAME="${NAME:-${CONTAINER_NAME:-qwen38-nvfp4}}"
	export CONTAINER_NAME="$NAME"
	export PORT="${PORT:-${HOST_PORT:-8000}}"
	export HOST_PORT="$PORT"
	export CTX="${CTX:-${MAX_MODEL_LEN:-16384}}"
	export SEQS="${SEQS:-${MAX_NUM_SEQS:-2}}"
	export GPU_MEM="${GPU_MEM:-${GPU_MEM_UTIL:-0.75}}"
	export MTP="${MTP:-0}"
	export PREFIX_CACHE="${PREFIX_CACHE:-0}"
	export FLASH_DGX_DIR="${FLASH_DGX_DIR:-${HOME}/qwen3.8-Flash-DGX}"
	export FLASH_REPO_URL="${FLASH_REPO_URL:-https://github.com/blazux/qwen3.8-Flash-DGX.git}"
	export FLASH_REPO_REF="${FLASH_REPO_REF:-c57881509af3dad83a28e59662fe3c4d29381628}"
	export VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:qwen38-flash-next}"
	export READY_TIMEOUT_SEC="${READY_TIMEOUT_SEC:-900}"
	export READY_POLL_SEC="${READY_POLL_SEC:-5}"
	export BASE_URL="${BASE_URL:-http://127.0.0.1:${PORT}}"
	export BENCH_DIR="${BENCH_DIR:-${HOME}/qwen38-bench}"
	export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-qwen38-spark}"
}

require_api_key() {
	if [[ -z "${VLLM_API_KEY:-}" ]]; then
		read -r -s -p "VLLM_API_KEY (input hidden): " VLLM_API_KEY
		echo
		export VLLM_API_KEY
	fi
	if [[ -z "${VLLM_API_KEY:-}" ]]; then
		echo "VLLM_API_KEY is required." >&2
		return 1
	fi
}

compose() {
	docker compose \
		--project-directory "$RECIPE_DIR" \
		--env-file "$RUNTIME_ENV" \
		-f "$COMPOSE_FILE" \
		"$@"
}
