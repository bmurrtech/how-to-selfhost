#!/usr/bin/env bash
# weights.sh — HF cache probe + docker-entrypoint download for NVFP4 checkpoint.
# shellcheck shell=bash
#
# Requires: VLLM_MODEL, HF_CACHE; optional HF_TOKEN, VLLM_IMAGE, HF_* timeouts.
# Sourcing script should also source pacman_progress.sh when calling run_download.

model_cache_dir() {
	local slug="${VLLM_MODEL//\//--}"
	echo "${HF_CACHE}/hub/models--${slug}"
}

snapshot_dir() {
	local base ref newest
	base="$(model_cache_dir)"
	[[ -d "$base" ]] || return 1
	if [[ -f "$base/refs/main" ]]; then
		ref="$(tr -d '[:space:]' <"$base/refs/main")"
		if [[ -n "$ref" && -d "$base/snapshots/$ref" ]]; then
			echo "$base/snapshots/$ref"
			return 0
		fi
	fi
	newest="$(find "$base/snapshots" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)"
	[[ -n "$newest" ]] && echo "$newest" && return 0
	return 1
}

file_bytes() {
	local path="$1" real
	real="$(readlink -f "$path" 2>/dev/null || true)"
	if [[ -n "$real" && -f "$real" ]]; then
		stat -c%s "$real" 2>/dev/null || echo 0
	else
		echo 0
	fi
}

# Print unique model-NNNN-of-MMMM.safetensors names from a safetensors index.json.
# Prefer Python JSON parse — grepping huge weight_maps (100k+ entries) over FUSE is flaky.
weights_index_shard_names() {
	local idx="$1"
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$idx" <<'PY'
import json, re, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, UnicodeDecodeError, json.JSONDecodeError) as e:
    sys.stderr.write(f"status: index parse failed: {e}\n")
    sys.exit(2)
wm = data.get("weight_map") or {}
pat = re.compile(r"^model-\d+-of-\d+\.safetensors$")
shards = sorted({v for v in wm.values() if isinstance(v, str) and pat.match(v)})
for s in shards:
    print(s)
PY
		return $?
	fi
	# Fallback: force text mode; unique via sort -u
	grep -aoE 'model-[0-9]+-of-[0-9]+\.safetensors' "$idx" | sort -u
}

# Returns 0 if local weights look complete enough to skip download.
weights_complete() {
	local snap incomplete expected_count missing found name sz idx
	local fsz dsz stem final f
	local -a shard_names=()
	snap="$(snapshot_dir 2>/dev/null)" || {
		echo "status: no snapshot under $(model_cache_dir)"
		return 1
	}

	echo "status: snapshot=$snap"

	incomplete=0
	while IFS= read -r -d '' f; do
		stem="${f%.incomplete}"
		final="${stem%.*}"
		if [[ -f "$final" ]]; then
			fsz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
			dsz="$(stat -c%s "$final" 2>/dev/null || echo 0)"
			if [[ "$dsz" -ge "$fsz" && "$dsz" -ge 1048576 ]]; then
				continue
			fi
		fi
		echo "status: active incomplete: $f"
		incomplete=$((incomplete + 1))
	done < <(find "$(model_cache_dir)" -type f \( -name '*.incomplete' -o -name '*.tmp' \) -print0 2>/dev/null)
	if [[ "$incomplete" -gt 0 ]]; then
		echo "status: active incomplete markers=$incomplete (not ready)"
		return 1
	fi

	if [[ ! -f "$snap/config.json" ]]; then
		echo "status: missing config.json"
		return 1
	fi

	idx=""
	for f in "$snap"/*.safetensors.index.json; do
		[[ -f "$f" ]] && idx="$f" && break
	done

	missing=0
	if [[ -n "$idx" ]]; then
		mapfile -t shard_names < <(weights_index_shard_names "$idx" || true)
		# Drop empty last element if any
		if [[ ${#shard_names[@]} -gt 0 && -z "${shard_names[-1]:-}" ]]; then
			unset 'shard_names[-1]'
		fi
		expected_count="${#shard_names[@]}"
		for name in "${shard_names[@]}"; do
			[[ -n "$name" ]] || continue
			if [[ ! -e "$snap/$name" ]]; then
				echo "status: missing shard $name"
				missing=$((missing + 1))
				continue
			fi
			sz="$(file_bytes "$snap/$name")"
			if [[ "$sz" -lt 1048576 ]]; then
				echo "status: tiny/empty shard $name ($sz bytes)"
				missing=$((missing + 1))
			fi
		done
		found="$(find "$snap" -maxdepth 1 -name 'model-*-of-*.safetensors' | wc -l | tr -d ' ')"
		echo "status: index expected=$expected_count links=$found missing=$missing"
		[[ "$expected_count" -gt 0 && "$missing" -eq 0 && "$found" -ge "$expected_count" ]] || return 1
	else
		found="$(find "$snap" -maxdepth 1 -name '*.safetensors' | wc -l | tr -d ' ')"
		echo "status: no index.json; safetensors_links=$found"
		[[ "$found" -ge 8 ]] || return 1
	fi

	if [[ -e "$snap/model-fp8-mtp-ple.safetensors" ]]; then
		sz="$(file_bytes "$snap/model-fp8-mtp-ple.safetensors")"
		echo "status: mtp-ple bytes=$sz"
		[[ "$sz" -ge 1048576 ]] || return 1
	fi

	echo "status: cache_size=$(du -sh "$(model_cache_dir)" 2>/dev/null | awk '{print $1}') — weights look complete"
	return 0
}

hf_docker_env() {
	HF_DL_ENV=(
		-e HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
		-e HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-300}"
		-e HF_HUB_ETAG_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-300}"
	)
	if declare -F local_ai_resolve_hf_token >/dev/null 2>&1; then
		local_ai_resolve_hf_token
	fi
	if [[ -n "${HF_TOKEN:-}" ]]; then
		HF_DL_ENV+=(-e HF_TOKEN="$HF_TOKEN" -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN")
		echo "auth: HF_TOKEN set"
	else
		echo "auth: anonymous (may hit rate limits)"
	fi
}

run_download() {
	local attempt max_attempts=3 rc
	local image="${VLLM_IMAGE:-vllm/vllm-openai:qwen38-flash-next}"
	local workers="${HF_MAX_WORKERS:-8}"
	local overall="${HF_DOWNLOAD_TIMEOUT_SEC:-14400}"

	mkdir -p "$HF_CACHE"
	hf_docker_env

	if ! docker image inspect "$image" >/dev/null 2>&1; then
		pacman_phase 5 "docker pull $image"
		docker pull "$image"
		pacman_progress_done "image ready"
	fi

	for attempt in $(seq 1 "$max_attempts"); do
		pacman_phase $((10 + attempt * 20)) "hf download attempt $attempt/$max_attempts"
		echo "console: concurrent download $VLLM_MODEL → $HF_CACHE"
		set +e
		timeout --signal=INT --kill-after=60 "$overall" \
			docker run --rm \
			"${HF_DL_ENV[@]}" \
			-v "${HF_CACHE}:/root/.cache/huggingface" \
			--entrypoint hf \
			"$image" \
			download "$VLLM_MODEL" \
			--max-workers "$workers"
		rc=$?
		set -e

		if [[ $rc -eq 0 ]]; then
			pacman_progress_done "download finished attempt $attempt"
			docker run --rm \
				-v "${HF_CACHE}:/root/.cache/huggingface" \
				--entrypoint bash \
				"$image" \
				-lc 'find /root/.cache/huggingface/hub -type f -name "*.incomplete" -delete 2>/dev/null; find /root/.cache/huggingface/hub -type f -name "*.tmp" -delete 2>/dev/null; true'
			if weights_complete; then
				return 0
			fi
			echo "console: exit 0 but completeness check failed — retrying"
		elif [[ $rc -eq 124 ]]; then
			echo "console: timed out after ${overall}s (attempt $attempt) — will resume" >&2
		else
			echo "console: download rc=$rc (attempt $attempt) — will resume if possible" >&2
		fi
		sleep $((attempt * 5))
	done
	return 1
}

# Native download when already inside a vLLM / HF-capable image (RunPod approach A).
run_download_native() {
	local attempt max_attempts=3 rc
	local workers="${HF_MAX_WORKERS:-8}"

	mkdir -p "$HF_CACHE"
	export HF_HOME="${HF_HOME:-$HF_CACHE}"
	if declare -F local_ai_resolve_hf_token >/dev/null 2>&1; then
		local_ai_resolve_hf_token
	fi
	if [[ -n "${HF_TOKEN:-}" ]]; then
		export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
		echo "auth: HF_TOKEN set"
	else
		echo "auth: anonymous (may hit rate limits)"
	fi

	if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
		echo "error: hf / huggingface-cli not on PATH (expected in vllm/qwen38 image)" >&2
		return 1
	fi

	for attempt in $(seq 1 "$max_attempts"); do
		pacman_phase $((10 + attempt * 20)) "hf download attempt $attempt/$max_attempts (native)"
		set +e
		if command -v hf >/dev/null 2>&1; then
			hf download "$VLLM_MODEL" --max-workers "$workers"
			rc=$?
		else
			huggingface-cli download "$VLLM_MODEL"
			rc=$?
		fi
		set -e
		if [[ $rc -eq 0 ]] && weights_complete; then
			pacman_progress_done "weights ready"
			return 0
		fi
		echo "console: download incomplete rc=$rc — retry" >&2
		sleep $((attempt * 5))
	done
	return 1
}
