#!/usr/bin/env bash
# check.sh — RTX PRO 6000 readiness (bare-metal Docker or native-in-vLLM).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"
# shellcheck source=../../../../scripts/lib/docker_nct.sh
source "${LIB_DIR}/docker_nct.sh"
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"

rtx_prefer_volume_cache

FAILS=0
WARNS=0
pass() { printf '[PASS] %-22s %s\n' "$1" "${2:-}"; }
warn() {
	printf '[WARN] %-22s %s\n' "$1" "${2:-}"
	WARNS=$((WARNS + 1))
}
fail() {
	printf '[FAIL] %-22s %s\n' "$1" "${2:-}"
	FAILS=$((FAILS + 1))
}
skip() { printf '[SKIP] %-22s %s\n' "$1" "${2:-}"; }

# Secrets presence (never print values)
if declare -F local_ai_resolve_hf_token >/dev/null 2>&1; then
	local_ai_resolve_hf_token
fi

mode="$(rtx_detect_exec_mode)"
echo "=== doctor / check ==="
echo "Qwen3-8-Flash-Next / RTX PRO 6000"
echo "Exec mode: ${mode}"
echo
ops_report_init
# Bridge local counters into ops_* for shared extras
ops_pass() { pass "$1" "$2"; }
ops_warn() { warn "$1" "$2"; }
ops_fail() { fail "$1" "$2"; }
ops_skip() { skip "$1" "$2"; }

# Fail closed on unpinned :latest (wrong image for Qwen3.8 PLE path)
img="${IMAGE:-${VLLM_IMAGE:-}}"
case "$img" in
vllm/vllm-openai:latest | *:latest)
	fail "Runtime image" "${img} — refuse :latest; use vllm/vllm-openai:qwen38-flash-next (or a pinned digest)"
	;;
*qwen38-flash-next*)
	pass "Runtime image" "$img"
	;;
"")
	warn "Runtime image" "unset (default at deploy: vllm/vllm-openai:qwen38-flash-next)"
	;;
*)
	warn "Runtime image" "${img} — expected vllm/vllm-openai:qwen38-flash-next"
	;;
esac

# Workspace / RunPod volume ergonomics (after rtx_prefer_volume_cache)
effective_root="$(rtx_resolved_volume_root 2>/dev/null || true)"
if [[ -n "$effective_root" ]]; then
	if [[ -n "${RTX_VOLUME_ROOT:-}" && "$effective_root" == "${RTX_VOLUME_ROOT}" ]]; then
		pass "Volume root" "RTX_VOLUME_ROOT=${RTX_VOLUME_ROOT} (HF_CACHE=${HF_CACHE:-unset})"
	elif [[ "$effective_root" == /workspace ]]; then
		if [[ -n "${RUNPOD_POD_ID:-}" ]]; then
			pass "Workspace" "/workspace writable (RunPod pod ${RUNPOD_POD_ID}; HF_CACHE=${HF_CACHE:-unset})"
		else
			pass "Workspace" "/workspace writable (HF_CACHE=${HF_CACHE:-unset})"
		fi
	else
		pass "Volume" "${effective_root} present (HF_CACHE=${HF_CACHE:-unset})"
	fi
elif [[ -n "${RTX_VOLUME_ROOT:-}" ]]; then
	warn "RTX_VOLUME_ROOT" "set to ${RTX_VOLUME_ROOT} but missing or not writable"
elif [[ -n "${RUNPOD_POD_ID:-}" ]]; then
	warn "Workspace" "RUNPOD_POD_ID set but no writable RTX_VOLUME_ROOT|/workspace|/runpod-volume — caches may fill container disk"
fi
if [[ -n "${RUNPOD_POD_ID:-}" && -z "$effective_root" && -z "${HF_CACHE:-}" ]]; then
	warn "Cache disk" "no volume root and HF_CACHE unset — prefer volume ≥200GB or RTX_VOLUME_ROOT"
fi
# Opt-in only: do not auto-detect global FUSE mounts as cache root
if [[ -z "${RTX_VOLUME_ROOT:-}" && -d /workspace-global ]]; then
	warn "RTX_VOLUME_ROOT" "/workspace-global present but unset — opt-in with RTX_VOLUME_ROOT=/workspace-global for FUSE weight persistence"
fi

# geesefs / FUSE: snapshot lstat 0-byte stubs while blobs are OK
if declare -F snapshot_dir >/dev/null 2>&1; then
	_snap=""
	_snap="$(snapshot_dir 2>/dev/null || true)"
	if [[ -n "$_snap" && -d "$_snap" ]]; then
		_stub=0
		_blob_ok=0
		while IFS= read -r -d '' _f; do
			_sz="$(stat -c%s "$_f" 2>/dev/null || echo 0)"
			if [[ "$_sz" == "0" ]]; then
				_stub=1
				_real="$(readlink -f "$_f" 2>/dev/null || true)"
				if [[ -n "$_real" && -f "$_real" ]]; then
					_rsz="$(stat -c%s "$_real" 2>/dev/null || echo 0)"
					[[ "$_rsz" != "0" ]] && _blob_ok=1
				fi
			fi
		done < <(
			find "$_snap" -maxdepth 1 -type f -print0 2>/dev/null
			find "$_snap" -maxdepth 1 -type l -print0 2>/dev/null
		)
		if [[ "$_stub" -eq 1 && "$_blob_ok" -eq 1 ]]; then
			warn "HF FUSE cache" "snapshot paths lstat 0-byte while blobs have size (geesefs stub/symlink flakiness) — prefer local metadata copy or re-hydrate"
		elif [[ "$_stub" -eq 1 ]]; then
			warn "HF FUSE cache" "snapshot files lstat 0-byte under ${_snap}"
		fi
	fi
fi

# Port in use?
port="${PORT:-8000}"
if command -v ss >/dev/null 2>&1; then
	if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
		warn "Port ${port}" "appears in use (deploy may fail or attach to existing)"
	else
		pass "Port ${port}" "available"
	fi
elif command -v lsof >/dev/null 2>&1; then
	if lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
		warn "Port ${port}" "appears in use (deploy may fail or attach to existing)"
	else
		pass "Port ${port}" "available"
	fi
else
	skip "Port ${port}" "ss/lsof not available"
fi

ops_doctor_mig
ops_doctor_runtime

# Effective critical knobs (no secrets)
echo
echo "--- effective knobs ---"
printf '  MODEL=%s\n' "${MODEL}"
printf '  CTX=%s SEQS=%s GPU_MEM=%s TP=%s\n' "${CTX:-}" "${SEQS:-}" "${GPU_MEM:-}" "${TENSOR_PARALLEL_SIZE:-}"
printf '  HF_CACHE=%s\n' "${HF_CACHE:-}"
printf '  VLLM_CACHE_ROOT=%s\n' "${VLLM_CACHE_ROOT:-unset}"
printf '  QUANTIZATION=%s\n' "${QUANTIZATION:-modelopt}"
printf '  PLE_MODE=%s VLLM_PLE_CPU_OFFLOAD=%s\n' "${PLE_MODE:-n/a}" "${VLLM_PLE_CPU_OFFLOAD:-0}"
printf '  HF_TOKEN=%s\n' "$([[ -n "${HF_TOKEN:-}" ]] && echo present || echo absent)"
if [[ "${TENSOR_PARALLEL_SIZE:-1}" == "1" || "${PROFILE_ID:-}" == "gpu-1" ]]; then
	warn "1× PLE" "use VLLM_PLE_CPU_OFFLOAD on qwen38-flash-next (not :latest); ~95GiB ngram OOM means wrong PLE path — do not use generic --cpu-offload-gb"
fi
echo

# 1) Compatible hardware
if command -v nvidia-smi >/dev/null 2>&1; then
	gpu_line="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)"
	count="$(rtx_gpu_count)"
	if echo "$gpu_line" | grep -qiE 'RTX.?PRO.?6000|RTX 6000'; then
		pass "GPU" "${count}× ${gpu_line}"
	else
		warn "GPU" "${count}× ${gpu_line:-unknown} (expected RTX PRO 6000)"
	fi
	if [[ "$count" -lt 1 || "$count" -gt 8 ]]; then
		fail "GPU count" "$count (recipe supports 1–8 on one node)"
	fi
	vram="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 || true)"
	pass "VRAM/GPU" "${vram}"
	drv="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)"
	pass "NVIDIA driver" "${drv:-ok} (not installed by recipe)"
else
	fail "GPU" "nvidia-smi not found"
fi

ram="$(rtx_host_ram_gib)"
pass "Host RAM" "~${ram} GiB (measured)"
pass "vCPUs" "$(nproc 2>/dev/null || echo '?')"

# 4) Storage
disk="$(rtx_disk_avail_gib "${HF_CACHE:-$HOME}")"
disk="${disk:-0}"
if [[ "$disk" -ge 200 ]]; then
	pass "Disk near cache" "~${disk} GiB free (${HF_CACHE})"
elif [[ "$disk" -ge 100 ]]; then
	warn "Disk near cache" "~${disk} GiB (prefer ≥200 or persistent volume)"
else
	fail "Disk near cache" "~${disk} GiB — 30 GB default container disks are inadequate"
fi

# 2) Runtime / 3) Docker vs native
if [[ "$mode" == "native" ]]; then
	if rtx_vllm_present; then
		pass "vLLM runtime" "present (native-in-container path)"
	else
		fail "vLLM runtime" "EXEC_MODE=native but vllm missing — use image vllm/vllm-openai:qwen38-flash-next"
	fi
	skip "Docker host" "not used in native mode"
else
	if [[ -f /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		if [[ "${ID:-}" == "ubuntu" ]]; then
			case "${VERSION_ID:-}" in
			22.04 | 24.04) pass "Ubuntu" "${VERSION_ID}" ;;
			*) warn "Ubuntu" "${VERSION_ID:-unknown} (Docker install tested on 22.04/24.04)" ;;
			esac
		else
			warn "OS" "${ID:-unknown} (Docker install helpers assume Ubuntu)"
		fi
	fi
	arch="$(uname -m 2>/dev/null || echo unknown)"
	if [[ "$arch" == "x86_64" ]]; then
		pass "Architecture" "$arch"
	else
		fail "Architecture" "$arch (expected x86_64 for metal Docker)"
	fi

	if docker_engine_ok; then
		pass "Docker" "$(docker --version 2>/dev/null | head -1)"
	else
		warn "Docker" "missing — just setup installs on Ubuntu"
	fi
	if docker_compose_ok; then
		pass "Compose" "ok"
	else
		warn "Compose" "missing — just setup installs"
	fi
	if docker info >/dev/null 2>&1; then
		if docker run --rm --gpus all ubuntu nvidia-smi >/dev/null 2>&1; then
			pass "Container GPU" "ok"
		else
			warn "Container GPU" "passthrough failed (NCT may need install)"
		fi
		if docker image inspect "$IMAGE" >/dev/null 2>&1; then
			pass "Runtime image" "$IMAGE"
		else
			warn "Runtime image" "$IMAGE missing (just setup pulls)"
		fi
	fi
fi

for t in just jq; do
	if command -v "$t" >/dev/null 2>&1; then
		pass "Tool:$t" "$(command -v "$t")"
	else
		warn "Tool:$t" "missing — run: bash scripts/ensure_mise.sh && mise install"
	fi
done
if ! command -v mise >/dev/null 2>&1; then
	warn "mise" "missing — bash scripts/ensure_mise.sh (or: curl -fsSL https://mise.run | sh)"
fi

if weights_complete >/tmp/local-ai-weights-check.txt 2>&1; then
	pass "Model cache" "weights complete"
else
	warn "Model cache" "incomplete (just setup)"
fi

echo
if [[ "$FAILS" -gt 0 ]]; then
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (${FAILS} fail, ${WARNS} warn)"
	echo "Next: just setup | just deploy"
	exit 1
fi
if [[ "$WARNS" -gt 0 ]]; then
	echo "STATUS: WARN"
	echo "RESULT: WARN (${WARNS} warn)"
else
	echo "STATUS: PASS"
	echo "RESULT: PASS"
fi
echo "Next: just probe | just setup | just deploy"
exit 0
