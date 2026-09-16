#!/usr/bin/env bash
# deploy.sh — Docker Compose (metal) or native vllm serve (in-container).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"
# shellcheck source=../../../../scripts/lib/docker_nct.sh
source "${LIB_DIR}/docker_nct.sh"

rtx_prefer_volume_cache
mode="$(rtx_detect_exec_mode)"
config_env_prefer_strong_api_key
require_api_key

detected="$(rtx_gpu_count)"
count="$(rtx_interactive_select "$RECIPE_DIR" "$detected")"
echo "GPUs selected: ${count} (profile=${PROFILE_ID:-unknown})"

if ! weights_complete >/dev/null; then
	echo "Weights incomplete — run: just setup" >&2
	exit 1
fi

prev_hash=""
[[ -f "$RUNTIME_ENV" ]] && prev_hash="$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || true)"
rtx_resolve_write "$RUNTIME_ENV"
new_hash="$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | head -1 | cut -d= -f2-)"

wait_api() {
	echo "Waiting for /v1/models (timeout ${READY_TIMEOUT_SEC}s)…"
	local start now elapsed code
	start=$(date +%s)
	while true; do
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			-H "Authorization: Bearer ${VLLM_API_KEY}" \
			"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
		if [[ "$code" == "200" ]]; then
			pacman_progress_done "API ready"
			return 0
		fi
		now=$(date +%s)
		elapsed=$((now - start))
		if [[ "$elapsed" -ge "$READY_TIMEOUT_SEC" ]]; then
			return 1
		fi
		pacman_progress $((elapsed * 90 / READY_TIMEOUT_SEC)) "waiting (${elapsed}s)"
		sleep "$READY_POLL_SEC"
	done
}

if [[ "$mode" == "docker" ]]; then
	if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
		echo "Image $IMAGE missing — run: just setup" >&2
		exit 1
	fi
	running=0
	health_ok=0
	if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
		running=1
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			-H "Authorization: Bearer ${VLLM_API_KEY}" \
			"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
		[[ "$code" == "200" ]] && health_ok=1
	fi
	if [[ "$running" -eq 1 && "$health_ok" -eq 1 && "$prev_hash" == "$new_hash" && "${FORCE_RESTART:-0}" != "1" ]]; then
		echo "SKIP: $NAME healthy CONFIG_HASH=${new_hash:0:12}…"
		exit 0
	fi
	export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-qwen38-rtx}"
	pacman_phase 20 "docker compose up -d"
	docker rm -f "$NAME" >/dev/null 2>&1 || true
	compose up -d --remove-orphans
	pacman_progress_done "compose up"
	if ! wait_api; then
		echo "Timeout. Logs:" >&2
		docker logs --tail 40 "$NAME" 2>&1 || true
		exit 1
	fi
	echo "deployed $NAME mode=docker profile=${PROFILE_ID} on 127.0.0.1:${PORT}"
	exit 0
fi

# --- native ---
# shellcheck disable=SC1090
set -a
# shellcheck source=/dev/null
source "$RUNTIME_ENV"
set +a

mkdir -p "${RECIPE_DIR}/.run"
PID_FILE="${RECIPE_DIR}/.run/vllm.pid"
LOG_FILE="${RECIPE_DIR}/.run/vllm.log"

if [[ -f "$PID_FILE" ]]; then
	old_pid="$(cat "$PID_FILE")"
	if kill -0 "$old_pid" 2>/dev/null; then
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			-H "Authorization: Bearer ${VLLM_API_KEY}" \
			"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
		if [[ "$code" == "200" && "$prev_hash" == "$new_hash" && "${FORCE_RESTART:-0}" != "1" ]]; then
			echo "SKIP: vllm pid=$old_pid healthy hash=${new_hash:0:12}…"
			exit 0
		fi
		kill "$old_pid" 2>/dev/null || true
		sleep 2
		kill -9 "$old_pid" 2>/dev/null || true
	fi
	rm -f "$PID_FILE"
fi

export HF_HOME="${HF_HOME:-$HF_CACHE}"
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"
if [[ -n "${VLLM_CACHE_ROOT:-}" ]]; then
	mkdir -p "${VLLM_CACHE_ROOT}"
	export VLLM_CACHE_ROOT
fi
export VLLM_PLE_CPU_OFFLOAD

cmd=(vllm serve "${MODEL}"
	--quantization "${QUANTIZATION:-modelopt}"
	--tensor-parallel-size "${TENSOR_PARALLEL_SIZE:-1}"
	--max-model-len "${CTX}"
	--max-num-seqs "${SEQS}"
	--max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}"
	--gpu-memory-utilization "${GPU_MEM}"
	--served-model-name "${SERVED_MODEL_NAME}"
	--host 0.0.0.0
	--port "${PORT}"
	--reasoning-parser qwen3
	--trust-remote-code
	--api-key "${VLLM_API_KEY}"
)
if [[ -n "${EXTRA_ARGS:-}" ]]; then
	# shellcheck disable=SC2206
	cmd+=(${EXTRA_ARGS})
fi
if ! command -v vllm >/dev/null 2>&1; then
	cmd=(python3 -m vllm.entrypoints.openai.api_server "${cmd[@]:1}")
fi

pacman_phase 20 "starting vllm serve (native, profile=${PROFILE_ID})"
nohup "${cmd[@]}" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
pacman_progress_done "pid=$(cat "$PID_FILE")"

if ! wait_api; then
	echo "Timeout. Tail log:" >&2
	tail -40 "$LOG_FILE" >&2 || true
	exit 1
fi
if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
	echo "vllm exited. Log:" >&2
	tail -40 "$LOG_FILE" >&2 || true
	exit 1
fi
echo "deployed mode=native profile=${PROFILE_ID} on :${PORT}"
