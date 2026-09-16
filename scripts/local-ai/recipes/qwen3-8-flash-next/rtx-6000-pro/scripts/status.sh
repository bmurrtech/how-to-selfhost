#!/usr/bin/env bash
# status.sh — RTX PRO 6000 operational status (docker or native).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"

rtx_prefer_volume_cache
mode="$(rtx_detect_exec_mode)"
state="ABSENT"
health="UNKNOWN"
PID_FILE="${RECIPE_DIR}/.run/vllm.pid"

if [[ "$mode" == "docker" ]]; then
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"; then
		state="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo unknown)"
		if [[ "$state" == "running" && -n "${VLLM_API_KEY:-}" ]]; then
			code="$(curl -sS -o /dev/null -w '%{http_code}' \
				-H "Authorization: Bearer ${VLLM_API_KEY}" \
				"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
			[[ "$code" == "200" ]] && health="HEALTHY" || health="STARTING_OR_UNHEALTHY (HTTP ${code:-000})"
		else
			health="n/a"
		fi
	fi
elif [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
	state="RUNNING"
	if [[ -n "${VLLM_API_KEY:-}" ]]; then
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			-H "Authorization: Bearer ${VLLM_API_KEY}" \
			"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
		[[ "$code" == "200" ]] && health="HEALTHY" || health="STARTING_OR_UNHEALTHY (HTTP ${code:-000})"
	fi
fi

ple="unknown"
profile="n/a"
if [[ -f "$RUNTIME_ENV" ]]; then
	ple="$(grep -E '^PLE_MODE=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || echo unknown)"
	profile="$(grep -E '^PROFILE_ID=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || echo n/a)"
	IMAGE="$(grep -E '^IMAGE=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || echo "$IMAGE")"
fi

printf '%-12s %s\n' "Model" "qwen3-8-flash-next"
printf '%-12s %s\n' "Target" "rtx-6000-pro"
printf '%-12s %s\n' "Mode" "$mode"
printf '%-12s %s\n' "GPUs" "$(rtx_gpu_count)"
printf '%-12s %s\n' "Profile" "$profile"
printf '%-12s %s\n' "State" "$(echo "$state" | tr '[:lower:]' '[:upper:]')"
printf '%-12s %s\n' "Health" "$health"
printf '%-12s %s\n' "API" "127.0.0.1:${PORT}"
printf '%-12s %s\n' "Image" "$IMAGE"
printf '%-12s %s\n' "PLE" "$ple"
printf '%-12s %s\n' "TP" "${TENSOR_PARALLEL_SIZE:-?}"
printf '%-12s %s\n' "Context" "${CTX:-?}"
