#!/usr/bin/env bash
# rtx_serve.sh — resolve .runtime.env for official qwen38-flash-next (metal / RunPod).
# shellcheck shell=bash
#
# Defaults push HW limits (dial down via .env / interactive prompt):
#   MAX_NUM_BATCHED_TOKENS=8192, SEQS=256, GPU_MEM=0.95, CTX=auto

rtx_escape() {
	# Values are written into a sourced .runtime.env — must be shell-quoted
	# (EXTRA_ARGS contains spaces / leading dashes that would otherwise execute).
	local s="${1//$'\n'/ }"
	printf '%q' "$s"
}

rtx_gpu_count() {
	if ! command -v nvidia-smi >/dev/null 2>&1; then
		echo 0
		return 0
	fi
	nvidia-smi -L 2>/dev/null | wc -l | tr -d ' '
}

rtx_host_ram_gib() {
	if [[ -r /proc/meminfo ]]; then
		awk '/MemTotal:/ {printf "%d", $2/1024/1024}' /proc/meminfo
	else
		echo 0
	fi
}

rtx_disk_avail_gib() {
	local path="${1:-${HF_CACHE:-$HOME}}"
	df -P "$path" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

# Coarse execution mode — no provider framework.
#   docker  = bare-metal (or host) launches upstream image via Docker Compose
#   native  = already inside intended vLLM runtime (e.g. RunPod qwen38 image)
rtx_vllm_present() {
	command -v vllm >/dev/null 2>&1 || python3 -c 'import vllm' >/dev/null 2>&1
}

rtx_in_container() {
	[[ -f /.dockerenv ]] || [[ -n "${RUNPOD_POD_ID:-}" ]] || [[ -n "${RUNPOD_GPU_COUNT:-}" ]] ||
		grep -qE '/docker|/kubepods|/containerd' /proc/1/cgroup 2>/dev/null
}

rtx_host_docker_usable() {
	command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# Override: EXEC_MODE=docker|native
rtx_detect_exec_mode() {
	if [[ -n "${EXEC_MODE:-}" ]]; then
		case "$EXEC_MODE" in
		docker | native) echo "$EXEC_MODE" ;;
		*)
			echo "error: EXEC_MODE must be docker or native (got ${EXEC_MODE})" >&2
			return 1
			;;
		esac
		return 0
	fi
	# Prefer native when vLLM is already on PATH inside a container / RunPod.
	if rtx_vllm_present && { rtx_in_container || ! rtx_host_docker_usable; }; then
		echo native
		return 0
	fi
	echo docker
}

# Prefer RTX_VOLUME_ROOT when set+writable (e.g. /workspace-global); else writable
# /workspace (RunPod Pods); else /runpod-volume.
# Explicit HF_CACHE / HF_HOME / VLLM_CACHE_ROOT always win.
# Note: recipe_bootstrap pre-fills HF_CACHE to $HOME/.cache/huggingface — treat
# that home default as unset so volume prefer can apply.
rtx_resolved_volume_root() {
	if [[ -n "${RTX_VOLUME_ROOT:-}" && -d "${RTX_VOLUME_ROOT}" && -w "${RTX_VOLUME_ROOT}" ]]; then
		printf '%s\n' "${RTX_VOLUME_ROOT}"
		return 0
	fi
	if [[ -d /workspace && -w /workspace ]]; then
		printf '%s\n' /workspace
		return 0
	fi
	if [[ -d /runpod-volume ]]; then
		printf '%s\n' /runpod-volume
		return 0
	fi
	return 1
}

rtx_prefer_volume_cache() {
	local root="" home_default="${HOME}/.cache/huggingface"
	root="$(rtx_resolved_volume_root 2>/dev/null || true)"
	if [[ -z "$root" ]]; then
		return 0
	fi
	if [[ -z "${HF_CACHE:-}" || "${HF_CACHE}" == "$home_default" ]]; then
		export HF_CACHE="${root}/huggingface"
	fi
	if [[ -z "${HF_HOME:-}" || "${HF_HOME}" == "$home_default" ]]; then
		export HF_HOME="${HF_CACHE}"
	fi
	export VLLM_CACHE_ROOT="${VLLM_CACHE_ROOT:-${root}/vllm-cache}"
	mkdir -p "${VLLM_CACHE_ROOT}" 2>/dev/null || true
}

rtx_load_profile() {
	local profile_file="$1"
	[[ -f "$profile_file" ]] || {
		echo "error: missing profile $profile_file" >&2
		return 1
	}
	local line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" != *=* ]] && continue
		key="${line%%=*}"
		val="${line#*=}"
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		[[ -z "$val" ]] && continue
		printf -v "$key" '%s' "$val"
		# shellcheck disable=SC2163
		export "$key"
	done <"$profile_file"
}

# PROFILE_OVERRIDE=4 or gpu-4 forces a named profile.
rtx_select_profile_file() {
	local recipe_dir="${1:?recipe_dir}"
	local count="${2:?gpu_count}"
	local override="${PROFILE_OVERRIDE:-}"
	local name status_file

	if [[ -n "$override" ]]; then
		name="${override#gpu-}"
		name="gpu-${name}"
		status_file="${recipe_dir}/profiles/${name}.env"
		[[ -f "$status_file" ]] || {
			echo "error: PROFILE_OVERRIDE=${override} not found" >&2
			return 1
		}
		echo "$status_file"
		return 0
	fi

	if [[ "$count" -lt 1 || "$count" -gt 8 ]]; then
		echo "error: GPU count $count out of range 1–8 for this recipe" >&2
		return 1
	fi
	status_file="${recipe_dir}/profiles/gpu-${count}.env"
	[[ -f "$status_file" ]] || {
		echo "error: missing ${status_file}" >&2
		return 1
	}
	echo "$status_file"
}

rtx_confirm_experimental() {
	local status="${PROFILE_STATUS:-experimental}"
	local count="${1:-?}"
	if [[ "$status" == "validated" || "$status" == "validated-intent" ]]; then
		return 0
	fi
	if [[ "${PROFILE_CONFIRM:-0}" == "1" ]]; then
		echo "PROFILE_CONFIRM=1 — proceeding with experimental ${count}-GPU profile"
		return 0
	fi
	if [[ ! -t 0 ]]; then
		echo "error: experimental ${count}-GPU profile requires interactive confirm or PROFILE_CONFIRM=1" >&2
		return 1
	fi
	echo "Detected: ${count}× GPU"
	echo "Profile status: ${status}"
	echo "This profile has not been benchmark-validated by this recipe."
	local ans
	read -r -p "Proceed? [y/N] " ans
	[[ "$ans" == "y" || "$ans" == "Y" ]] || {
		echo "aborted" >&2
		return 1
	}
}

# Apply profile file + push-limit defaults for selected GPU count.
# Profile values win; TENSOR_PARALLEL_SIZE defaults to count when unset.
rtx_apply_profile_defaults() {
	local recipe_dir="${1:?recipe_dir}"
	local count="${2:?gpu_count}"
	local profile
	profile="$(rtx_select_profile_file "$recipe_dir" "$count")" || return 1
	rtx_load_profile "$profile"
	export CTX="${CTX:-auto}"
	export SEQS="${SEQS:-256}"
	export GPU_MEM="${GPU_MEM:-0.95}"
	export MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"
	export TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-$count}"
	export ENABLE_PREFIX_CACHING="${ENABLE_PREFIX_CACHING:-1}"
	export MOE_BACKEND="${MOE_BACKEND:-marlin}"
	export NO_FLASHINFER_AUTOTUNE="${NO_FLASHINFER_AUTOTUNE:-1}"
	export ENABLE_AUTO_TOOL_CHOICE="${ENABLE_AUTO_TOOL_CHOICE:-1}"
	export TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-qwen3_coder}"
}

# Interactive: confirm/override GPU count + push-limit serve defaults.
# Non-interactive: RTX_INTERACTIVE=0 or non-TTY — still loads profile so TP=GPU count.
# Returns selected GPU count on stdout (last line); prompts go to stderr.
rtx_interactive_select() {
	local recipe_dir="${1:?recipe_dir}"
	local detected="${2:?detected}"
	local count="$detected" ans

	if [[ "${RTX_INTERACTIVE:-}" == "0" ]] || { [[ "${RTX_INTERACTIVE:-}" != "1" ]] && [[ ! -t 0 ]]; }; then
		rtx_apply_profile_defaults "$recipe_dir" "$count" || return 1
		rtx_confirm_experimental "$count" || return 1
		echo "$count"
		return 0
	fi

	echo "=== RTX serve profile ===" >&2
	echo "Detected GPUs: ${detected}" >&2
	read -r -p "GPUs in this node [${detected}]: " ans || true
	if [[ -n "${ans:-}" ]]; then
		if [[ "$ans" =~ ^[1-8]$ ]]; then
			count="$ans"
		else
			echo "error: enter an integer 1–8" >&2
			return 1
		fi
	fi
	export PROFILE_OVERRIDE="$count"

	rtx_apply_profile_defaults "$recipe_dir" "$count" || return 1

	echo >&2
	if [[ "${PROFILE_ID:-}" == "gpu-1" || "${PLE_MODE:-}" == "cpu" ]]; then
		echo "Proposed serve knobs (1× / conservative bring-up — dial up later):" >&2
	else
		echo "Proposed serve knobs (profile defaults — dial down if needed):" >&2
	fi
	echo "  profile=${PROFILE_ID} status=${PROFILE_STATUS} PLE=${PLE_MODE}" >&2
	echo "  --tensor-parallel-size ${TENSOR_PARALLEL_SIZE}" >&2
	echo "  --max-model-len ${CTX}" >&2
	echo "  --max-num-batched-tokens ${MAX_NUM_BATCHED_TOKENS}" >&2
	echo "  --max-num-seqs ${SEQS}" >&2
	echo "  --gpu-memory-utilization ${GPU_MEM}" >&2
	echo "  --moe-backend ${MOE_BACKEND}  prefix-caching=${ENABLE_PREFIX_CACHING}" >&2
	echo "  VLLM_PLE_CPU_OFFLOAD=${VLLM_PLE_CPU_OFFLOAD:-0} (specialized PLE path; not --cpu-offload-gb)" >&2
	read -r -p "Accept these defaults? [Y/n] " ans || true
	ans="${ans:-Y}"
	if [[ "$ans" == "n" || "$ans" == "N" ]]; then
		read -r -p "max-model-len [${CTX}]: " ans && [[ -n "$ans" ]] && CTX="$ans"
		read -r -p "max-num-batched-tokens [${MAX_NUM_BATCHED_TOKENS}]: " ans && [[ -n "$ans" ]] && MAX_NUM_BATCHED_TOKENS="$ans"
		read -r -p "max-num-seqs [${SEQS}]: " ans && [[ -n "$ans" ]] && SEQS="$ans"
		read -r -p "gpu-memory-utilization [${GPU_MEM}]: " ans && [[ -n "$ans" ]] && GPU_MEM="$ans"
		read -r -p "tensor-parallel-size [${TENSOR_PARALLEL_SIZE}]: " ans && [[ -n "$ans" ]] && TENSOR_PARALLEL_SIZE="$ans"
		export CTX SEQS GPU_MEM MAX_NUM_BATCHED_TOKENS TENSOR_PARALLEL_SIZE
	fi

	rtx_confirm_experimental "$count" || return 1
	echo "$count"
}

# Append common high-throughput vLLM flags into EXTRA_ARGS if not already present.
rtx_apply_serve_extras() {
	local extras=()
	if [[ "${EXTRA_ARGS:-}" == *"--cpu-offload-gb"* ]]; then
		echo "warn: EXTRA_ARGS contains --cpu-offload-gb — not the Qwen3.8 PLE strategy; prefer VLLM_PLE_CPU_OFFLOAD / profile PLE_MODE" >&2
	fi
	[[ "${NO_FLASHINFER_AUTOTUNE:-1}" == "1" ]] && extras+=(--no-enable-flashinfer-autotune)
	if [[ "${ENABLE_PREFIX_CACHING:-1}" == "1" ]]; then
		extras+=(--enable-prefix-caching)
	else
		extras+=(--no-enable-prefix-caching)
	fi
	[[ -n "${MOE_BACKEND:-}" ]] && extras+=(--moe-backend "${MOE_BACKEND}")
	if [[ "${ENABLE_AUTO_TOOL_CHOICE:-1}" == "1" ]]; then
		extras+=(--enable-auto-tool-choice)
		extras+=(--tool-call-parser "${TOOL_CALL_PARSER:-qwen3_coder}")
	fi
	# Merge with any operator EXTRA_ARGS
	if [[ -n "${EXTRA_ARGS:-}" ]]; then
		# shellcheck disable=SC2206
		extras+=(${EXTRA_ARGS})
	fi
	EXTRA_ARGS="${extras[*]}"
	export EXTRA_ARGS
}

rtx_resolve_write() {
	local out="${1:?output path}"
	local model="${MODEL:-${VLLM_MODEL:-nvidia/Qwen3.8-Flash-Next-NVFP4}}"
	local image="${IMAGE:-${VLLM_IMAGE:-vllm/vllm-openai:qwen38-flash-next}}"
	local name="${NAME:-${CONTAINER_NAME:-qwen38-nvfp4}}"
	local port="${PORT:-${HOST_PORT:-8000}}"
	local ctx="${CTX:-${MAX_MODEL_LEN:-auto}}"
	local seqs="${SEQS:-${MAX_NUM_SEQS:-256}}"
	local gpu_mem="${GPU_MEM:-${GPU_MEM_UTIL:-0.95}}"
	local tp="${TENSOR_PARALLEL_SIZE:-${TP:-1}}"
	local batched="${MAX_NUM_BATCHED_TOKENS:-8192}"
	local shm="${SHM_SIZE:-16g}"
	local hf_cache="${HF_CACHE:-${HOME}/.cache/huggingface}"
	local hf_home="${HF_HOME:-$hf_cache}"
	local vllm_cache="${VLLM_CACHE_ROOT:-}"
	local ple_offload="${VLLM_PLE_CPU_OFFLOAD:-0}"
	local quant="${QUANTIZATION:-modelopt}"
	local served="${SERVED_MODEL_NAME:-qwen3.8-flash-next}"
	local api_key="${VLLM_API_KEY:-}"
	local hash_src hash

	if [[ -n "$vllm_cache" ]]; then
		mkdir -p "$vllm_cache" 2>/dev/null || true
	fi

	rtx_apply_serve_extras

	hash_src="${model}|${image}|${name}|${port}|${ctx}|${seqs}|${gpu_mem}|${tp}|${batched}|${ple_offload}|${quant}|${served}|${EXTRA_ARGS:-}|${PROFILE_ID:-}|${vllm_cache}"
	if command -v sha256sum >/dev/null 2>&1; then
		hash="$(printf '%s' "$hash_src" | sha256sum | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		hash="$(printf '%s' "$hash_src" | shasum -a 256 | awk '{print $1}')"
	else
		hash="nohash"
	fi

	umask 077
	cat >"$out" <<EOF
MODEL=$(rtx_escape "$model")
VLLM_MODEL=$(rtx_escape "$model")
IMAGE=$(rtx_escape "$image")
VLLM_IMAGE=$(rtx_escape "$image")
NAME=$(rtx_escape "$name")
CONTAINER_NAME=$(rtx_escape "$name")
PORT=$(rtx_escape "$port")
HOST_PORT=$(rtx_escape "$port")
CTX=$(rtx_escape "$ctx")
MAX_MODEL_LEN=$(rtx_escape "$ctx")
SEQS=$(rtx_escape "$seqs")
MAX_NUM_SEQS=$(rtx_escape "$seqs")
GPU_MEM=$(rtx_escape "$gpu_mem")
GPU_MEM_UTIL=$(rtx_escape "$gpu_mem")
TENSOR_PARALLEL_SIZE=$(rtx_escape "$tp")
MAX_NUM_BATCHED_TOKENS=$(rtx_escape "$batched")
SHM_SIZE=$(rtx_escape "$shm")
HF_CACHE=$(rtx_escape "$hf_cache")
HF_HOME=$(rtx_escape "$hf_home")
VLLM_CACHE_ROOT=$(rtx_escape "$vllm_cache")
VLLM_PLE_CPU_OFFLOAD=$(rtx_escape "$ple_offload")
QUANTIZATION=$(rtx_escape "$quant")
SERVED_MODEL_NAME=$(rtx_escape "$served")
VLLM_API_KEY=$(rtx_escape "$api_key")
ENABLE_PREFIX_CACHING=$(rtx_escape "${ENABLE_PREFIX_CACHING:-1}")
MOE_BACKEND=$(rtx_escape "${MOE_BACKEND:-marlin}")
NO_FLASHINFER_AUTOTUNE=$(rtx_escape "${NO_FLASHINFER_AUTOTUNE:-1}")
ENABLE_AUTO_TOOL_CHOICE=$(rtx_escape "${ENABLE_AUTO_TOOL_CHOICE:-1}")
TOOL_CALL_PARSER=$(rtx_escape "${TOOL_CALL_PARSER:-qwen3_coder}")
EXTRA_ARGS=$(rtx_escape "${EXTRA_ARGS:-}")
PROFILE_ID=$(rtx_escape "${PROFILE_ID:-}")
PROFILE_STATUS=$(rtx_escape "${PROFILE_STATUS:-}")
PLE_MODE=$(rtx_escape "${PLE_MODE:-}")
COMPOSE_PROJECT_NAME=$(rtx_escape "${COMPOSE_PROJECT_NAME:-qwen38-rtx}")
CONFIG_HASH=$(rtx_escape "$hash")
EOF
	chmod 600 "$out"
}
