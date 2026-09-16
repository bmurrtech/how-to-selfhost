#!/usr/bin/env bash
# stop.sh — stop docker compose stack or native vllm pid.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"

mode="$(rtx_detect_exec_mode)"

if [[ "$mode" == "docker" ]]; then
	export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-qwen38-rtx}"
	if [[ -f "$RUNTIME_ENV" ]]; then
		compose down --remove-orphans || true
	fi
	docker rm -f "$NAME" >/dev/null 2>&1 || true
	echo "Stopped $NAME (docker)"
	exit 0
fi

PID_FILE="${RECIPE_DIR}/.run/vllm.pid"
if [[ -f "$PID_FILE" ]]; then
	pid="$(cat "$PID_FILE")"
	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		sleep 2
		kill -9 "$pid" 2>/dev/null || true
		echo "Stopped vllm pid=$pid (native)"
	else
		echo "Stale pid file ($pid)"
	fi
	rm -f "$PID_FILE"
else
	echo "No pid file — nothing to stop"
	pkill -f 'vllm serve' 2>/dev/null || true
fi
