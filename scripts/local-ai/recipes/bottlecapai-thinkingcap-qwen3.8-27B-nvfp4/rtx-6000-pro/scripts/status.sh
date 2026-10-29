#!/usr/bin/env bash
# status.sh — concise operational status (read-only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./recipe_bootstrap_local.sh
source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"

state="ABSENT"
health="UNKNOWN"
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"; then
	state="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo unknown)"
	oom="$(docker inspect -f '{{.State.OOMKilled}}' "$NAME" 2>/dev/null || echo false)"
	if [[ "$state" == "running" && -n "${VLLM_API_KEY:-}" ]]; then
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			-H "Authorization: Bearer ${VLLM_API_KEY}" \
			"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
		if [[ "$code" == "200" ]]; then
			health="HEALTHY"
		else
			health="STARTING_OR_UNHEALTHY (HTTP ${code:-000})"
		fi
	elif [[ "$oom" == "true" ]]; then
		health="OOMKilled"
	else
		health="n/a"
	fi
fi

img="$IMAGE"
served="$SERVED_MODEL_NAME"
if [[ -f "$RUNTIME_ENV" ]]; then
	img="$(grep -E '^IMAGE=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || echo "$IMAGE")"
	served="$(grep -E '^SERVED_MODEL_NAME=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || echo "$SERVED_MODEL_NAME")"
fi

printf '%-12s %s\n' "Model" "$served"
printf '%-12s %s\n' "Target" "spark"
printf '%-12s %s\n' "Runtime" "vLLM (dense NVFP4)"
printf '%-12s %s\n' "State" "$(echo "$state" | tr '[:lower:]' '[:upper:]')"
printf '%-12s %s\n' "Health" "$health"
printf '%-12s %s\n' "API" "127.0.0.1:${PORT}"
printf '%-12s %s\n' "Image" "$img"
printf '%-12s %s\n' "Context" "$CTX"
printf '%-12s %s\n' "MTP" "${MTP:-0}"
printf '%-12s %s\n' "Seqs" "$SEQS"
printf '%-12s %s\n' "GPU mem" "$GPU_MEM"
