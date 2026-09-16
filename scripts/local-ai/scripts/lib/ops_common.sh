#!/usr/bin/env bash
# ops_common.sh — PASS/WARN/FAIL reporting + doctor extras (versions, MIG, port).
# shellcheck shell=bash
#
# After recipe_bootstrap:
#   source "${LIB_DIR}/ops_common.sh"
#   ops_report_init
#   ops_doctor_runtime   # optional block
#   ops_report_finish "Next: just probe"

ops_report_init() {
	OPS_FAILS=0
	OPS_WARNS=0
}

ops_pass() { printf '[PASS] %-22s %s\n' "$1" "${2:-}"; }
ops_warn() {
	printf '[WARN] %-22s %s\n' "$1" "${2:-}"
	OPS_WARNS=$((OPS_WARNS + 1))
}
ops_fail() {
	printf '[FAIL] %-22s %s\n' "$1" "${2:-}"
	OPS_FAILS=$((OPS_FAILS + 1))
}
ops_skip() { printf '[SKIP] %-22s %s\n' "$1" "${2:-}"; }

ops_report_finish() {
	local next="${1:-}"
	echo
	if [[ "${OPS_FAILS:-0}" -gt 0 ]]; then
		echo "RESULT: FAIL (${OPS_FAILS} fail, ${OPS_WARNS:-0} warn)"
		[[ -n "$next" ]] && printf '\nNext:\n  %s\n' "$next"
		return 1
	fi
	if [[ "${OPS_WARNS:-0}" -gt 0 ]]; then
		echo "RESULT: WARN (${OPS_WARNS} warn)"
	else
		echo "RESULT: PASS"
	fi
	[[ -n "$next" ]] && printf '\nNext:\n  %s\n' "$next"
	return 0
}

# Redact common secret patterns from stdin → stdout (for snapshot/logs snippets).
ops_redact_stream() {
	sed -E \
		-e 's/(VLLM_API_KEY|OPENAI_API_KEY|HF_TOKEN|HUGGING_FACE_HUB_TOKEN|Authorization: Bearer)[=: ]+[^[:space:]]+/\1=***REDACTED***/gI' \
		-e 's/(--api-key[[:space:]]+)[^[:space:]]+/\1***REDACTED***/g'
}

ops_port_in_use() {
	local port="${1:?port}"
	if command -v ss >/dev/null 2>&1; then
		ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"
		return $?
	fi
	if command -v lsof >/dev/null 2>&1; then
		lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
		return $?
	fi
	return 2
}

ops_doctor_port() {
	local port="${PORT:-8000}"
	local st
	if ops_port_in_use "$port"; then
		ops_warn "Port ${port}" "appears in use"
	else
		st=$?
		if [[ "$st" -eq 2 ]]; then
			ops_skip "Port ${port}" "ss/lsof not available"
		else
			ops_pass "Port ${port}" "available"
		fi
	fi
}

ops_doctor_mig() {
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		ops_skip "MIG" "nvidia-smi missing"
		return 0
	fi
	local mig
	mig="$(nvidia-smi -q 2>/dev/null | awk -F': ' '/MIG Mode/{getline; if ($1 ~ /Current/) {print $2; exit}}' | tr -d '[:space:]' || true)"
	if [[ -z "$mig" ]]; then
		ops_skip "MIG" "not reported"
		return 0
	fi
	case "${mig,,}" in
	enabled)
		ops_warn "MIG" "enabled — recipe expects full GPU(s); verify MIG devices match TP"
		;;
	disabled)
		ops_pass "MIG" "disabled (full GPU)"
		;;
	*)
		ops_warn "MIG" "Current=${mig}"
		;;
	esac
}

ops_doctor_runtime() {
	local drv cuda torch_ok vllm_ver pyver

	if command -v nvidia-smi >/dev/null 2>&1; then
		drv="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)"
		ops_pass "Driver" "${drv:-unknown}"
		cuda="$(nvidia-smi 2>/dev/null | awk -F'CUDA Version: ' '/CUDA Version/{print $2; exit}' | awk '{print $1}')"
		if [[ -n "$cuda" ]]; then
			ops_pass "CUDA (driver)" "$cuda"
		else
			ops_skip "CUDA (driver)" "not parsed"
		fi
	fi

	if command -v python3 >/dev/null 2>&1; then
		pyver="$(
			python3 - <<'PY' 2>/dev/null || true
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
		)"
		if [[ -n "$pyver" ]]; then
			ops_pass "Python" "$pyver"
		else
			ops_skip "Python" "unavailable"
		fi
		torch_ok="$(
			python3 - <<'PY' 2>/dev/null || true
try:
    import torch
    print(f"torch={torch.__version__} cuda_available={torch.cuda.is_available()}")
except Exception as e:
    print(f"ERR:{e}")
PY
		)"
		if [[ "$torch_ok" == ERR:* ]]; then
			ops_skip "PyTorch" "not importable (${torch_ok#ERR:})"
		elif [[ -n "$torch_ok" ]]; then
			if [[ "$torch_ok" == *"cuda_available=True"* ]]; then
				ops_pass "PyTorch" "$torch_ok"
			elif [[ "$torch_ok" == *"cuda_available=False"* ]]; then
				ops_warn "PyTorch" "$torch_ok"
			else
				ops_pass "PyTorch" "$torch_ok"
			fi
		else
			ops_skip "PyTorch" "not importable"
		fi
	else
		ops_skip "Python" "python3 missing"
	fi

	if command -v vllm >/dev/null 2>&1; then
		vllm_ver="$(vllm --version 2>/dev/null | head -1 || true)"
		ops_pass "vLLM CLI" "${vllm_ver:-present}"
	elif python3 -c 'import vllm' >/dev/null 2>&1; then
		vllm_ver="$(python3 -c 'import vllm; print(getattr(vllm, "__version__", "unknown"))' 2>/dev/null || echo unknown)"
		ops_pass "vLLM py" "$vllm_ver"
	else
		ops_skip "vLLM" "not on PATH (ok for docker-only metal)"
	fi
}

# Print resolved inference knobs from .runtime.env / env (never secrets).
ops_config_show() {
	local src="${1:-${RUNTIME_ENV:-}}"
	local mode="${2:-}"
	echo "=== effective configuration ==="
	[[ -n "$mode" ]] && echo "Exec mode:              ${mode}"
	echo "Model:                  ${MODEL:-${VLLM_MODEL:-unset}}"
	echo "Served name:            ${SERVED_MODEL_NAME:-unset}"
	echo "Image:                  ${IMAGE:-${VLLM_IMAGE:-unset}}"
	echo "Quantization:           ${QUANTIZATION:-modelopt/default}"
	echo "max_model_len (CTX):    ${CTX:-${MAX_MODEL_LEN:-unset}}"
	echo "gpu_memory_utilization: ${GPU_MEM:-${GPU_MEM_UTIL:-unset}}"
	echo "max_num_seqs:           ${SEQS:-${MAX_NUM_SEQS:-unset}}"
	echo "max_num_batched_tokens: ${MAX_NUM_BATCHED_TOKENS:-unset}"
	echo "tensor_parallel_size:   ${TENSOR_PARALLEL_SIZE:-${TP:-unset}}"
	echo "prefix_caching:         ${ENABLE_PREFIX_CACHING:-${PREFIX_CACHE:-unset}}"
	echo "moe_backend:            ${MOE_BACKEND:-unset}"
	echo "PLE / offload:          ${PLE_MODE:-n/a} / ${VLLM_PLE_CPU_OFFLOAD:-0}"
	echo "HF_CACHE:               ${HF_CACHE:-unset}"
	echo "HF_HOME:                ${HF_HOME:-${HF_CACHE:-unset}}"
	echo "VLLM_CACHE_ROOT:        ${VLLM_CACHE_ROOT:-unset}"
	echo "PORT / BASE_URL:        ${PORT:-unset} / ${BASE_URL:-unset}"
	echo "Profile:                ${PROFILE_ID:-n/a} (${PROFILE_STATUS:-})"
	if [[ -n "${RUNPOD_POD_ID:-}" ]]; then
		echo "RunPod pod:             ${RUNPOD_POD_ID}"
		echo "RunPod GPU count env:   ${RUNPOD_GPU_COUNT:-unset}"
	fi
	echo "VLLM_API_KEY:           $([[ -n "${VLLM_API_KEY:-}" ]] && echo present || echo absent)"
	echo "HF_TOKEN:               $([[ -n "${HF_TOKEN:-}" ]] && echo present || echo absent)"
	if [[ -n "$src" && -f "$src" ]]; then
		echo "Runtime env:            ${src}"
		local hash
		hash="$(grep -E '^CONFIG_HASH=' "$src" 2>/dev/null | head -1 | cut -d= -f2- || true)"
		[[ -n "$hash" ]] && echo "CONFIG_HASH:            ${hash:0:16}…"
	fi
	echo "RESULT: PASS (config shown; secrets redacted)"
}
