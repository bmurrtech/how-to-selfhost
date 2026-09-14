#!/usr/bin/env bash
# benchmark.sh — short vllm bench serve against the live API (timestamped report).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap

require_api_key

# Tokenizer uses HF MODEL; API requests use SERVED_MODEL_NAME (else 404 Not Found).
if [[ -z "${SERVED_MODEL_NAME:-}" && -f "$RUNTIME_ENV" ]]; then
	SERVED_MODEL_NAME="$(grep -E '^SERVED_MODEL_NAME=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || true)"
fi
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-flash-next}"

NUM_PROMPTS="${NUM_PROMPTS:-20}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}"
DATASET_NAME="${DATASET_NAME:-random}"
INPUT_LEN="${INPUT_LEN:-256}"
OUTPUT_LEN="${OUTPUT_LEN:-128}"
REPORT_TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="${BENCH_DIR}/bench-serve-${REPORT_TS}.txt"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--num-prompts)
		NUM_PROMPTS="$2"
		shift 2
		;;
	--max-concurrency)
		MAX_CONCURRENCY="$2"
		shift 2
		;;
	--dataset-name)
		DATASET_NAME="$2"
		shift 2
		;;
	--base-url)
		BASE_URL="$2"
		shift 2
		;;
	--input-len)
		INPUT_LEN="$2"
		shift 2
		;;
	--output-len)
		OUTPUT_LEN="$2"
		shift 2
		;;
	-h | --help)
		sed -n '1,12p' "$0"
		exit 0
		;;
	*)
		echo "Unknown arg: $1" >&2
		exit 1
		;;
	esac
done

mkdir -p "$BENCH_DIR"
pacman_phase 10 "checking server ${BASE_URL}"
if ! curl -fsS "${BASE_URL}/v1/models" -H "Authorization: Bearer ${VLLM_API_KEY}" >/dev/null; then
	echo "Server not healthy at ${BASE_URL}" >&2
	exit 1
fi
pacman_progress_done "server healthy"

pacman_phase 30 "vllm bench serve (prompts=${NUM_PROMPTS} conc=${MAX_CONCURRENCY})"
echo "Report: ${REPORT_FILE}"

bench_docker() {
	local entry=()
	if [[ "${1:-}" == "entrypoint" ]]; then
		entry=(--entrypoint vllm)
		shift
	fi
	docker run --rm --network host \
		"${entry[@]}" \
		-e OPENAI_API_KEY="${VLLM_API_KEY}" \
		-e VLLM_API_KEY="${VLLM_API_KEY}" \
		-e HF_TOKEN="${HF_TOKEN:-}" \
		-e HUGGING_FACE_HUB_TOKEN="${HF_TOKEN:-}" \
		-v "${HF_CACHE}:/root/.cache/huggingface" \
		"$VLLM_IMAGE" \
		bench serve \
		--backend vllm \
		--base-url "$BASE_URL" \
		--model "$MODEL" \
		--served-model-name "$SERVED_MODEL_NAME" \
		--tokenizer "$MODEL" \
		--dataset-name "$DATASET_NAME" \
		--num-prompts "$NUM_PROMPTS" \
		--max-concurrency "$MAX_CONCURRENCY" \
		--random-input-len "$INPUT_LEN" \
		--random-output-len "$OUTPUT_LEN" \
		--percentile-metrics ttft,tpot,itl,e2el
}

set +e
bench_docker 2>&1 | tee "$REPORT_FILE"
bench_rc=${PIPESTATUS[0]}
set -e

if [[ $bench_rc -ne 0 ]]; then
	pacman_phase 50 "retry: entrypoint vllm bench serve"
	set +e
	bench_docker entrypoint 2>&1 | tee -a "$REPORT_FILE"
	bench_rc=${PIPESTATUS[0]}
	set -e
fi

if [[ $bench_rc -eq 0 ]]; then
	pacman_progress_done "bench complete"
	echo "Saved: $REPORT_FILE"
else
	echo "Bench failed (rc=$bench_rc). See $REPORT_FILE" >&2
	exit "$bench_rc"
fi
