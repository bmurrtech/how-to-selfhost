#!/usr/bin/env bash
# deploy.sh — resolve config → compose up (idempotent via CONFIG_HASH).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./recipe_bootstrap_local.sh
source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"
# shellcheck source=./resolve_dense_serve.sh
source "${SCRIPT_DIR}/resolve_dense_serve.sh"

require_api_key

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	echo "Image $IMAGE missing — run: just setup" >&2
	exit 1
fi

if ! weights_complete >/dev/null; then
	echo "Weights incomplete — run: just setup" >&2
	exit 1
fi

stop_conflicting_port8000

if [[ -w /proc/sys/vm/drop_caches ]]; then
	sync
	echo 3 >/proc/sys/vm/drop_caches || true
elif command -v sudo >/dev/null 2>&1; then
	sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
fi

prev_hash=""
if [[ -f "$RUNTIME_ENV" ]]; then
	prev_hash="$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || true)"
fi

resolve_dense_serve_write "$RUNTIME_ENV"
new_hash="$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | head -1 | cut -d= -f2-)"

running=0
if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
	running=1
fi

health_ok=0
if [[ "$running" -eq 1 && -n "${VLLM_API_KEY:-}" ]]; then
	code="$(curl -sS -o /dev/null -w '%{http_code}' \
		-H "Authorization: Bearer ${VLLM_API_KEY}" \
		"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
	[[ "$code" == "200" ]] && health_ok=1
fi

if [[ "$running" -eq 1 && "$health_ok" -eq 1 && "$prev_hash" == "$new_hash" && "${FORCE_RESTART:-0}" != "1" ]]; then
	echo "SKIP: $NAME already healthy with matching CONFIG_HASH=${new_hash:0:12}…"
	echo "Next: just status | just probe"
	exit 0
fi

pacman_phase 20 "docker compose up -d"
docker rm -f "$NAME" >/dev/null 2>&1 || true
compose up -d --remove-orphans
pacman_progress_done "compose up issued"

echo "Waiting for /v1/models (timeout ${READY_TIMEOUT_SEC}s)…"
start=$(date +%s)
while true; do
	code="$(curl -sS -o /dev/null -w '%{http_code}' \
		-H "Authorization: Bearer ${VLLM_API_KEY}" \
		"http://127.0.0.1:${PORT}/v1/models" 2>/dev/null || true)"
	if [[ "$code" == "200" ]]; then
		pacman_progress_done "API ready"
		break
	fi
	now=$(date +%s)
	elapsed=$((now - start))
	if [[ "$elapsed" -ge "$READY_TIMEOUT_SEC" ]]; then
		echo "FAILED: API ready timeout after ${READY_TIMEOUT_SEC}s — check logs: just logs" >&2
		docker logs --tail 40 "$NAME" 2>&1 || true
		exit 1
	fi
	st="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo missing)"
	if [[ "$st" != "running" ]]; then
		echo "FAILED: container not running ($st). Logs:" >&2
		docker logs --tail 40 "$NAME" 2>&1 || true
		exit 1
	fi
	pacman_progress $((elapsed * 90 / READY_TIMEOUT_SEC)) "waiting API (${elapsed}s)"
	sleep "$READY_POLL_SEC"
done

echo
echo "deployed $NAME on :$PORT (hash=${new_hash:0:12}…)"
echo "Next: just probe | just status"
