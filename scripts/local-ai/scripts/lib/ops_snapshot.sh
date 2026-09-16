#!/usr/bin/env bash
# ops_snapshot.sh — one redacted diagnostic bundle.
# shellcheck shell=bash

ops_snapshot_run() {
	local stamp dir
	stamp="$(date -u +%Y%m%dT%H%M%SZ)"
	dir="${RECIPE_DIR}/.run/snapshot-${stamp}"
	mkdir -p "$dir"

	echo "=== snapshot ==="
	echo "Dir: $dir"

	{
		echo "recipe_dir=${RECIPE_DIR}"
		echo "timestamp=${stamp}"
		echo "host=$(hostname 2>/dev/null || echo unknown)"
		echo "model=${MODEL:-}"
		echo "served=${SERVED_MODEL_NAME:-}"
		echo "image=${IMAGE:-}"
		echo "port=${PORT:-}"
		echo "exec_mode=${EXEC_MODE:-}"
		[[ -n "${RUNPOD_POD_ID:-}" ]] && echo "runpod_pod_id=${RUNPOD_POD_ID}"
	} >"${dir}/meta.txt"

	if declare -F ops_config_show >/dev/null 2>&1; then
		ops_config_show "${RUNTIME_ENV:-}" >"${dir}/config.txt" 2>&1 || true
	fi

	if command -v nvidia-smi >/dev/null 2>&1; then
		nvidia-smi >"${dir}/nvidia-smi.txt" 2>&1 || true
		nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv >"${dir}/gpu-short.csv" 2>&1 || true
	fi

	{
		command -v vllm >/dev/null 2>&1 && vllm --version
		python3 - <<'PY' 2>/dev/null || true
try:
    import torch, vllm
    print("torch", getattr(torch, "__version__", "?"))
    print("torch.cuda.is_available", torch.cuda.is_available())
    print("vllm", getattr(vllm, "__version__", "?"))
except Exception as e:
    print("import_err", e)
PY
	} >"${dir}/versions.txt" 2>&1 || true

	# Last errors from logs (best-effort)
	local log_snip="${dir}/logs-errors.txt"
	if [[ -f "${RECIPE_DIR}/.run/vllm.log" ]]; then
		if declare -F ops_redact_stream >/dev/null 2>&1; then
			tail -n 400 "${RECIPE_DIR}/.run/vllm.log" | ops_redact_stream | grep -nEi 'error|cuda|oom|exception|failed' | tail -80 >"$log_snip" || true
		else
			tail -n 400 "${RECIPE_DIR}/.run/vllm.log" | grep -nEi 'error|cuda|oom|exception|failed' | tail -80 >"$log_snip" || true
		fi
	elif command -v docker >/dev/null 2>&1 && [[ -n "${NAME:-}" ]] && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"; then
		docker logs --tail 400 "$NAME" 2>&1 | {
			if declare -F ops_redact_stream >/dev/null 2>&1; then ops_redact_stream; else cat; fi
		} | grep -nEi 'error|cuda|oom|exception|failed' | tail -80 >"$log_snip" || true
	else
		echo "(no container/native log found)" >"$log_snip"
	fi

	# Latest bench report if any
	if [[ -d "${BENCH_DIR:-}" ]]; then
		local latest=""
		# shellcheck disable=SC2012
		latest="$(ls -1t "${BENCH_DIR}"/bench-serve-*.txt 2>/dev/null | head -1 || true)"
		if [[ -n "$latest" ]]; then
			if declare -F ops_redact_stream >/dev/null 2>&1; then
				ops_redact_stream <"$latest" >"${dir}/last-benchmark.txt" 2>/dev/null || true
			else
				cp "$latest" "${dir}/last-benchmark.txt" 2>/dev/null || true
			fi
		fi
	fi

	# Never copy .env / runtime secrets raw — redact runtime env keys of interest
	if [[ -f "${RUNTIME_ENV:-}" ]]; then
		grep -E '^(MODEL|IMAGE|NAME|PORT|HF_CACHE|HF_HOME|VLLM_CACHE_ROOT|CTX|SEQS|GPU_MEM|TENSOR_PARALLEL_SIZE|MAX_NUM_BATCHED_TOKENS|QUANTIZATION|SERVED_MODEL_NAME|PROFILE_ID|CONFIG_HASH|ENABLE_PREFIX_CACHING|MOE_BACKEND)=' \
			"$RUNTIME_ENV" >"${dir}/runtime.env.safe" 2>/dev/null || true
	fi

	echo "STATUS: PASS"
	echo "RESULT: PASS"
	echo "Snapshot: $dir"
	echo "Share that directory (secrets redacted)."
}
