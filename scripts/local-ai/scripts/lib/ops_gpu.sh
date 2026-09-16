#!/usr/bin/env bash
# ops_gpu.sh — thin nvidia-smi wrappers.
# shellcheck shell=bash

ops_gpu_show() {
	echo "=== gpu ==="
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		echo "STATUS: FAIL"
		echo "RESULT: FAIL (nvidia-smi not found)"
		return 1
	fi
	nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,memory.free,power.draw,power.limit,temperature.gpu,clocks.sm,clocks.mem \
		--format=csv
	echo
	nvidia-smi
	echo "STATUS: PASS"
	echo "RESULT: PASS"
}

ops_gpu_watch() {
	local interval="${1:-2}"
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		echo "RESULT: FAIL (nvidia-smi not found)" >&2
		return 1
	fi
	if command -v watch >/dev/null 2>&1; then
		exec watch -n "$interval" nvidia-smi
	fi
	echo "watch(1) missing — looping nvidia-smi every ${interval}s (Ctrl-C to stop)"
	while true; do
		clear 2>/dev/null || true
		date -u +%Y-%m-%dT%H:%M:%SZ
		nvidia-smi
		sleep "$interval"
	done
}
