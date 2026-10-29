#!/usr/bin/env bash
# check.sh — read-only readiness for bottlecapai-thinkingcap-qwen3.8-27B-nvfp4 / spark.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./recipe_bootstrap_local.sh
source "${SCRIPT_DIR}/recipe_bootstrap_local.sh"
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
echo "ThinkingCap-Qwen3.8-27B-NVFP4 / RTX PRO 6000"
print_model_banner
echo

# --- architecture ---
if arch="$(uname -m 2>/dev/null)"; then
	if [[ "$arch" == "x86_64" ]]; then
		pass "Architecture" "$arch"
	else
		warn "Architecture" "$arch (expected x86_64 on RTX host)"
	fi
else
	fail "Architecture" "uname missing"
fi

if [[ -f /etc/os-release ]]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	pass "OS" "${NAME:-linux} ${VERSION_ID:-}"
else
	skip "OS" "no os-release"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
	if gpu_line="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"; then
		if echo "$gpu_line" | grep -qiE '6000|Blackwell|RTX'; then
			pass "GPU" "$gpu_line"
		else
			warn "GPU" "$gpu_line (expected RTX PRO 6000 / Blackwell)"
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

if [[ -r /proc/meminfo ]]; then
	mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
	mem_gi=$((mem_kb / 1024 / 1024))
	pass "Host memory" "~${mem_gi} GiB"
else
	skip "Host memory" "/proc/meminfo unreadable"
fi

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

if docker info >/dev/null 2>&1; then
	if docker run --rm --gpus all ubuntu nvidia-smi >/dev/null 2>&1; then
		pass "Container GPU" "nvidia-smi via --gpus all"
	else
		fail "Container GPU" "GPU passthrough failed"
	fi
else
	skip "Container GPU" "docker unreachable"
fi

for t in just jq yq shellcheck shfmt; do
	if command -v "$t" >/dev/null 2>&1; then
		pass "Tool:$t" "$(command -v "$t")"
	else
		warn "Tool:$t" "missing (run: mise install)"
	fi
done

# --- HF token (gated model) ---
if declare -F local_ai_resolve_hf_token >/dev/null 2>&1; then
	local_ai_resolve_hf_token
fi
if [[ -n "${HF_TOKEN:-}" ]]; then
	pass "HF_TOKEN" "present (value not shown)"
else
	fail "HF_TOKEN" "absent — required for gated ${MODEL}"
fi

if weights_complete >/tmp/local-ai-weights-check.txt 2>&1; then
	pass "Model cache" "weights complete"
else
	fail "Model cache" "incomplete (run: just setup)"
	tail -3 /tmp/local-ai-weights-check.txt 2>/dev/null | while read -r line; do
		warn "Model cache" "$line"
	done || true
fi

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
	pass "Runtime image" "$IMAGE"
else
	fail "Runtime image" "$IMAGE missing (just setup)"
fi

if [[ -f "${RECIPE_DIR}/recipe.yaml" && -f "${RECIPE_DIR}/compose.yaml" && -f "${RECIPE_DIR}/config/serve.env" ]]; then
	pass "Config files" "recipe/compose/serve.env present"
else
	fail "Config files" "missing recipe artifacts"
fi

if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"; then
	st="$(docker inspect -f '{{.State.Status}} oom={{.State.OOMKilled}}' "$NAME" 2>/dev/null || echo missing)"
	pass "Service state" "$NAME $st"
else
	skip "Service state" "container $NAME not created"
fi

ops_doctor_mig
ops_doctor_runtime

port="${PORT:-8000}"
if ops_port_in_use "$port"; then
	if docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -q ":${port}->"; then
		warn "Port ${port}" "in use by another container — stop qwen38-nvfp4 (flash-next) first"
	else
		ops_warn "Port ${port}" "appears in use"
	fi
else
	st=$?
	if [[ "$st" -eq 2 ]]; then
		ops_skip "Port ${port}" "ss/lsof not available"
	else
		ops_pass "Port ${port}" "available"
	fi
fi

echo
echo "--- effective knobs ---"
printf '  MODEL=%s IMAGE=%s\n' "${MODEL}" "${IMAGE}"
printf '  SERVED=%s CTX=%s SEQS=%s GPU_MEM=%s MTP=%s\n' \
	"${SERVED_MODEL_NAME}" "${CTX:-}" "${SEQS:-}" "${GPU_MEM:-}" "${MTP:-}"
printf '  HF_CACHE=%s PORT=%s\n' "${HF_CACHE:-}" "${PORT:-}"
echo

if [[ "$FAILS" -gt 0 ]]; then
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (${FAILS} fail, ${WARNS} warn)"
	echo
	echo "Next:"
	echo "  export HF_TOKEN=… && just setup"
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
echo "  just setup | just deploy | just probe"
exit 0
