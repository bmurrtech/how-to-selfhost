#!/usr/bin/env bash
# resolve_serve.sh — port of blazux/qwen3.8-Flash-DGX@c578815 scripts/serve.sh (MODE=nvfp4 only).
# Writes gitignored .runtime.env for docker compose (env + command fragments).
# shellcheck shell=bash
#
# Usage:
#   source resolve_serve.sh
#   resolve_serve_write "$RECIPE_DIR/.runtime.env"
#
# Reads: MODEL/VLLM_MODEL, HF_CACHE, IMAGE, NAME, PORT, CTX, SEQS, GPU_MEM, MTP,
#        PREFIX_CACHE, YARN, KV_DTYPE, DET_TOPK, EXACT_TOPK, PAD_M4, DRAFT_VOCAB,
#        MADVISE, PREWARM, WORKERS, MAX_NUM_BATCHED_TOKENS, VLLM_API_KEY, EXTRA, BASE

resolve_snapshot_in() {
	local model="${MODEL:-${VLLM_MODEL:?VLLM_MODEL required}}"
	local hf_cache="${HF_CACHE:?HF_CACHE required}"
	local repo_dir snap_host ref rev snap_name

	repo_dir="$hf_cache/hub/models--${model//\//--}"
	snap_host=""
	for ref in main master; do
		rev="$(tr -d '[:space:]' <"$repo_dir/refs/$ref" 2>/dev/null || true)"
		if [[ -n "$rev" && -d "$repo_dir/snapshots/$rev" ]]; then
			snap_host="$repo_dir/snapshots/$rev/"
			break
		fi
	done
	if [[ -z "$snap_host" ]]; then
		local d newest=""
		for d in "$repo_dir"/snapshots/*/; do
			[[ -d "$d" ]] || continue
			case "$d" in
			*-fp8hybrid*) continue ;;
			esac
			if [[ -z "$newest" || "$d" -nt "$newest" ]]; then
				newest="$d"
			fi
		done
		snap_host="$newest"
	fi
	if [[ -z "$snap_host" ]]; then
		echo "!! checkpoint not found under $repo_dir" >&2
		return 1
	fi
	snap_name="$(basename "$snap_host")"
	# In-container path (HF_CACHE mounted at /hf)
	echo "/hf/hub/models--${model//\//--}/snapshots/$snap_name"
}

resolve_split_ops() {
	local image="${IMAGE:?IMAGE required}"
	local base="${BASE:-}"
	if [[ -z "$base" ]]; then
		base="$(docker image inspect -f '{{index .Config.Labels "qwen38.base"}}' "$image" 2>/dev/null || true)"
	fi
	if [[ "$base" == "v0.29" ]]; then
		echo '["vllm::unified_attention_with_output","vllm::unified_mla_attention_with_output","vllm::mamba_mixer2","vllm::mamba_mixer","vllm::short_conv","vllm::qwen4_exp_compute_ple_ngram_ids","vllm::qwen4_exp_ple_short_conv","vllm::qwen4_exp_qsa_with_output","vllm::linear_attention","vllm::qwen_gdn_attention_core","vllm::qwen_gdn_attention_core_fused_norm_packed","vllm::sparse_attn_indexer","vllm::ple_mmap_lookup_ids"]'
	else
		echo '["vllm::unified_attention_with_output","vllm::unified_mla_attention_with_output","vllm::mamba_mixer2","vllm::mamba_mixer","vllm::short_conv","vllm::qwen3_8_flash_next_ple_short_conv","vllm::qwen3_8_flash_next_qsa_with_output","vllm::linear_attention","vllm::qwen_gdn_attention_core","vllm::qwen_gdn_attention_core_fused_norm_packed","vllm::sparse_attn_indexer","vllm::ple_mmap_lookup"]'
	fi
	# Export detected base for callers / .runtime.env
	RESOLVED_BASE="${base:-preview}"
}

# Escape a value for inclusion in a KEY=value env file (no shell expansion on read by compose).
_runtime_escape() {
	# Values are written as KEY=value without shell eval on read by compose env-file.
	printf '%s' "${1//$'\n'/ }"
}

# Write .runtime.env consumed by compose.yaml (interpolation + container env).
resolve_serve_write() {
	local out="${1:?output path}"
	local model="${MODEL:-${VLLM_MODEL:-nvidia/Qwen3.8-Flash-Next-NVFP4}}"
	local image="${IMAGE:-qwen38-flash-dgx:c578815}"
	local name="${NAME:-qwen38-nvfp4}"
	local port="${PORT:-8000}"
	local ctx="${CTX:-65536}"
	local seqs="${SEQS:-2}"
	local gpu_mem="${GPU_MEM:-0.75}"
	local mtp="${MTP:-0}"
	local prefix_cache="${PREFIX_CACHE:-1}"
	local yarn="${YARN:-0}"
	local kv_dtype="${KV_DTYPE:-auto}"
	local det_topk="${DET_TOPK:-1}"
	local exact_topk="${EXACT_TOPK:-0}"
	local pad_m4="${PAD_M4:-0}"
	local draft_vocab="${DRAFT_VOCAB:-1}"
	local madvise="${MADVISE:-random}"
	local prewarm="${PREWARM:-0}"
	local workers="${WORKERS:-${VLLM_PLE_MMAP_WORKERS:-32}}"
	local batched="${MAX_NUM_BATCHED_TOKENS:-8192}"
	local shm="${SHM_SIZE:-16g}"
	local hf_cache="${HF_CACHE:-${HOME}/.cache/huggingface}"
	local snap_in split_ops pc_arg allow_long yarn_ovr spec_json draft_env
	local api_extra=""

	MODEL="$model"
	IMAGE="$image"
	HF_CACHE="$hf_cache"
	export MODEL IMAGE HF_CACHE

	snap_in="$(resolve_snapshot_in)" || return 1
	split_ops="$(resolve_split_ops)"

	if [[ "${RESOLVED_BASE:-}" == "v0.29" ]]; then
		if [[ "$kv_dtype" != "auto" ]]; then
			echo "!! KV_DTYPE=$kv_dtype not supported on v0.29 base" >&2
			return 1
		fi
		if [[ "$pad_m4" != "0" ]]; then
			echo "!! PAD_M4 ignored on v0.29 base" >&2
			pad_m4=0
		fi
	fi

	pc_arg="--no-enable-prefix-caching"
	[[ "$prefix_cache" == "1" ]] && pc_arg="--enable-prefix-caching"

	allow_long=0
	yarn_ovr=""
	if [[ "$yarn" != "0" ]]; then
		yarn_ovr='{"text_config": {"rope_parameters": {"mrope_interleaved": true, "mrope_section": [11, 11, 10], "rope_type": "yarn", "rope_theta": 10000000, "partial_rotary_factor": 0.25, "factor": 4.0, "original_max_position_embeddings": 262144}}}'
		allow_long=1
	fi

	spec_json=""
	if [[ "$mtp" != "0" ]]; then
		if [[ "$yarn" != "0" ]]; then
			spec_json="{\"method\":\"mtp\",\"num_speculative_tokens\":${mtp},\"max_model_len\":${ctx}}"
		else
			spec_json="{\"method\":\"mtp\",\"num_speculative_tokens\":${mtp}}"
		fi
	fi

	draft_env=""
	case "$draft_vocab" in
	0 | "") ;;
	1) draft_env="/opt/llm/draft_vocab_65536.npy" ;;
	*) draft_env="$draft_vocab" ;;
	esac

	api_extra="${EXTRA:-}"

	# Config hash inputs (no secrets): used by deploy for idempotency.
	local hash_src hash
	hash_src="${image}|${name}|${port}|${ctx}|${seqs}|${gpu_mem}|${mtp}|${prefix_cache}|${yarn}|${kv_dtype}|${snap_in}|${split_ops}|${batched}|${det_topk}|${exact_topk}|${pad_m4}|${draft_vocab}|${madvise}|${prewarm}|${workers}"
	hash="$(printf '%s' "$hash_src" | sha256sum | awk '{print $1}')"

	umask 077
	cat >"$out" <<EOF
# Generated by resolve_serve.sh — do not commit
IMAGE=$(_runtime_escape "$image")
NAME=$(_runtime_escape "$name")
PORT=$(_runtime_escape "$port")
HF_CACHE=$(_runtime_escape "$hf_cache")
SHM_SIZE=$(_runtime_escape "$shm")
SNAP_IN=$(_runtime_escape "$snap_in")
CTX=$(_runtime_escape "$ctx")
SEQS=$(_runtime_escape "$seqs")
GPU_MEM=$(_runtime_escape "$gpu_mem")
KV_DTYPE=$(_runtime_escape "$kv_dtype")
MAX_NUM_BATCHED_TOKENS=$(_runtime_escape "$batched")
PREFIX_CACHE_ARG=$(_runtime_escape "$pc_arg")
SPLIT_OPS=$(_runtime_escape "$split_ops")
YARN_OVR=$(_runtime_escape "$yarn_ovr")
SPEC_JSON=$(_runtime_escape "$spec_json")
EXTRA_ARGS=$(_runtime_escape "$api_extra")
CONFIG_HASH=$hash
RESOLVED_BASE=$(_runtime_escape "${RESOLVED_BASE:-preview}")
SERVED_MODEL_NAME=qwen3.8-flash-next
MODE=nvfp4
MTP=$(_runtime_escape "$mtp")
PREFIX_CACHE=$(_runtime_escape "$prefix_cache")
YARN=$(_runtime_escape "$yarn")
HF_HOME=/hf
HF_HUB_OFFLINE=1
VLLM_PLE_MMAP=1
VLLM_PLE_MMAP_WORKERS=$(_runtime_escape "$workers")
VLLM_PLE_MMAP_PREWARM=$(_runtime_escape "$prewarm")
VLLM_PLE_MMAP_MADVISE=$(_runtime_escape "$madvise")
VLLM_QSA_EXACT_TOPK=$(_runtime_escape "$exact_topk")
VLLM_FP8_PAD_M4=$(_runtime_escape "$pad_m4")
VLLM_USE_FLASHINFER_SAMPLER=1
VLLM_ALLOW_LONG_MAX_MODEL_LEN=$(_runtime_escape "$allow_long")
EOF

	if [[ "$det_topk" == "1" ]]; then
		cat >>"$out" <<EOF
VLLM_QSA_DET_TOPK=1
VLLM_QSA_DET_LIB=/opt/llm/kernel-det/_C_det.so
EOF
	fi
	if [[ -n "$draft_env" ]]; then
		printf 'VLLM_MTP_DRAFT_VOCAB=%s\n' "$(_runtime_escape "$draft_env")" >>"$out"
	fi
	if [[ -n "${VLLM_API_KEY:-}" ]]; then
		printf 'VLLM_API_KEY=%s\n' "$(_runtime_escape "$VLLM_API_KEY")" >>"$out"
	fi

	echo "resolve: wrote $out (hash=${hash:0:12}… snap=$snap_in base=${RESOLVED_BASE:-preview})"
}
