#!/usr/bin/env bash
# check.sh — read-only readiness for qwen3-8-flash-next / spark (PRD §31).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"

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

ops_pass() { pass "$1" "$2"; }
ops_warn() { warn "$1" "$2"; }
ops_fail() { fail "$1" "$2"; }
ops_skip() { skip "$1" "$2"; }

echo "=== doctor / check ==="
echo "Qwen3-8-Flash-Next / Spark"
echo

# --- architecture ---
if arch="$(uname -m 2>/dev/null)"; then
	if [[ "$arch" == "aarch64" ]]; then
		pass "Architecture" "$arch"
	else
		warn "Architecture" "$arch (expected aarch64 on Spark)"
	fi
else
	fail "Architecture" "uname missing"
fi

# --- DGX OS (best-effort) ---
if [[ -f /etc/dgx-release ]]; then
	pass "DGX OS" "$(head -1 /etc/dgx-release 2>/dev/null || echo present)"
elif [[ -f /etc/os-release ]]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	warn "DGX OS" "not detected (${NAME:-linux} ${VERSION_ID:-})"
else
	skip "DGX OS" "no os-release"
fi

# --- GPU / GB10 ---
if command -v nvidia-smi >/dev/null 2>&1; then
	if gpu_line="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"; then
		if echo "$gpu_line" | grep -qiE 'GB10|Spark'; then
			pass "GPU" "$gpu_line"
		else
			warn "GPU" "$gpu_line (expected GB10)"
		fi
	else
		fail "GPU" "nvidia-smi failed"
	fi
	drv="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)"
	pass "NVIDIA driver" "${drv:-ok}"
else
	fail "GPU" "nvidia-smi not found"
	fail "NVIDIA driver" "nvidia-smi not found"
fi

# --- unified memory ---
if [[ -r /proc/meminfo ]]; then
	mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
	mem_gi=$((mem_kb / 1024 / 1024))
	if [[ "$mem_gi" -ge 100 ]]; then
		pass "Unified memory" "~${mem_gi} GiB"
	else
		warn "Unified memory" "~${mem_gi} GiB (Spark ~121 GiB expected)"
	fi
else
	skip "Unified memory" "/proc/meminfo unreadable"
fi

# --- storage / NVMe ---
if command -v lsblk >/dev/null 2>&1; then
	if lsblk -d -o NAME,TRAN 2>/dev/null | grep -qi nvme; then
		pass "NVMe" "present"
	else
		warn "NVMe" "no nvme transport in lsblk (PLE mmap prefers NVMe)"
	fi
else
	skip "NVMe" "lsblk missing"
fi
if df -h "$HF_CACHE" >/dev/null 2>&1 || df -h "${HOME}" >/dev/null 2>&1; then
	avail="$(df -h "$HF_CACHE" 2>/dev/null | awk 'NR==2{print $4}' || df -h "$HOME" | awk 'NR==2{print $4}')"
	avail_gib="$(df -P "$HF_CACHE" 2>/dev/null | awk 'NR==2{printf "%d", $4/1024/1024}' || df -P "$HOME" | awk 'NR==2{printf "%d", $4/1024/1024}')"
	avail_gib="${avail_gib:-0}"
	if [[ "$avail_gib" -ge 100 ]]; then
		pass "Storage" "avail ${avail} (~${avail_gib} GiB) near cache"
	elif [[ "$avail_gib" -ge 50 ]]; then
		warn "Storage" "avail ${avail} (~${avail_gib} GiB) — prefer ≥100 GiB for weights"
	else
		fail "Storage" "avail ${avail} (~${avail_gib} GiB) — too small for NVFP4 cache"
	fi
else
	skip "Storage" "df failed"
fi

# --- Docker ---
if command -v docker >/dev/null 2>&1; then
	pass "Docker" "$(docker --version 2>/dev/null | head -1)"
else
	fail "Docker" "not found"
fi

if docker compose version >/dev/null 2>&1; then
	pass "Docker Compose" "$(docker compose version --short 2>/dev/null || echo ok)"
else
	fail "Docker Compose" "not found"
fi

if docker info >/dev/null 2>&1; then
	pass "Docker daemon" "reachable"
else
	fail "Docker daemon" "unreachable"
fi

# --- container GPU (expensive; skip if docker down) ---
if docker info >/dev/null 2>&1; then
	if docker run --rm --gpus all ubuntu nvidia-smi >/dev/null 2>&1; then
		pass "Container GPU" "nvidia-smi via --gpus all"
	else
		fail "Container GPU" "GPU passthrough failed"
	fi
else
	skip "Container GPU" "docker unreachable"
fi

# --- mise tools ---
for t in just jq yq shellcheck shfmt; do
	if command -v "$t" >/dev/null 2>&1; then
		pass "Tool:$t" "$(command -v "$t")"
	else
		warn "Tool:$t" "missing (run: mise install)"
	fi
done

# --- model cache / PLE ---
if weights_complete >/tmp/local-ai-weights-check.txt 2>&1; then
	pass "Model cache" "weights complete"
	pass "PLE data" "mtp-ple present or not required"
else
	fail "Model cache" "incomplete (see just setup)"
	tail -3 /tmp/local-ai-weights-check.txt 2>/dev/null | while read -r line; do
		warn "Model cache" "$line"
	done || true
	# PLE file check separately
	if snap="$(snapshot_dir 2>/dev/null)"; then
		if [[ -e "$snap/model-fp8-mtp-ple.safetensors" ]]; then
			pass "PLE data" "model-fp8-mtp-ple.safetensors"
		else
			warn "PLE data" "ple tensor not found in snapshot (may still serve)"
		fi
	else
		fail "PLE data" "no snapshot"
	fi
fi

# --- runtime image ---
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
	base="$(docker image inspect -f '{{index .Config.Labels "qwen38.base"}}' "$IMAGE" 2>/dev/null || true)"
	pass "Runtime image" "$IMAGE (qwen38.base=${base:-unset})"
else
	fail "Runtime image" "$IMAGE missing (just setup)"
fi

# --- config validity ---
if [[ -f "${RECIPE_DIR}/recipe.yaml" && -f "${RECIPE_DIR}/compose.yaml" && -f "${RECIPE_DIR}/config/serve.env" ]]; then
	pass "Config files" "recipe/compose/serve.env present"
else
	fail "Config files" "missing recipe artifacts"
fi

# --- service state ---
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"; then
	st="$(docker inspect -f '{{.State.Status}} oom={{.State.OOMKilled}}' "$NAME" 2>/dev/null || echo missing)"
	pass "Service state" "$NAME $st"
else
	skip "Service state" "container $NAME not created"
fi

ops_doctor_mig
ops_doctor_runtime
ops_doctor_port

echo
echo "--- effective knobs ---"
printf '  MODEL=%s IMAGE=%s\n' "${MODEL}" "${IMAGE}"
printf '  CTX=%s SEQS=%s GPU_MEM=%s MTP=%s\n' "${CTX:-}" "${SEQS:-}" "${GPU_MEM:-}" "${MTP:-}"
printf '  HF_CACHE=%s\n' "${HF_CACHE:-}"
echo

echo
if [[ "$FAILS" -gt 0 ]]; then
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (${FAILS} fail, ${WARNS} warn)"
	echo
	echo "Next:"
	echo "  just setup"
	exit 1
fi

if [[ "$WARNS" -gt 0 ]]; then
	echo "STATUS: WARN"
	echo "RESULT: WARN (${WARNS} warn)"
else
	echo "STATUS: PASS"
	echo "RESULT: PASS"
fi
echo
echo "Next:"
echo "  just probe | just deploy"
exit 0
