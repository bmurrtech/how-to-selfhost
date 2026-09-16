#!/usr/bin/env bash
# ops_bench.sh — shared vllm bench serve defaults + load sweep.
# shellcheck shell=bash
#
# Default workload (override via env / flags):
#   INPUT_LEN=4096 OUTPUT_LEN=256 NUM_PROMPTS=50 REQUEST_RATE=2

ops_bench_defaults() {
	NUM_PROMPTS="${NUM_PROMPTS:-50}"
	INPUT_LEN="${INPUT_LEN:-4096}"
	OUTPUT_LEN="${OUTPUT_LEN:-256}"
	DATASET_NAME="${DATASET_NAME:-random}"
	# Prefer request-rate; MAX_CONCURRENCY kept as optional override.
	REQUEST_RATE="${REQUEST_RATE:-2}"
	MAX_CONCURRENCY="${MAX_CONCURRENCY:-}"
}

ops_bench_parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--num-prompts)
			NUM_PROMPTS="$2"
			shift 2
			;;
		--request-rate)
			REQUEST_RATE="$2"
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
			echo "usage: just benchmark [--num-prompts N] [--request-rate R] [--input-len N] [--output-len N]"
			return 2
			;;
		*)
			echo "Unknown arg: $1" >&2
			return 1
			;;
		esac
	done
}

ops_bench_ensure_model_name() {
	if [[ -z "${SERVED_MODEL_NAME:-}" && -f "${RUNTIME_ENV:-}" ]]; then
		SERVED_MODEL_NAME="$(grep -E '^SERVED_MODEL_NAME=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || true)"
	fi
	SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.8-flash-next}"
}

ops_bench_health() {
	if ! curl -fsS "${BASE_URL}/v1/models" -H "Authorization: Bearer ${VLLM_API_KEY}" >/dev/null; then
		echo "STATUS: FAIL"
		echo "RESULT: FAIL (server not healthy at ${BASE_URL})" >&2
		return 1
	fi
}

ops_bench_cmd_args() {
	local -a args=(
		bench
		serve
		--backend
		vllm
		--base-url
		"$BASE_URL"
		--model
		"$MODEL"
		--served-model-name
		"$SERVED_MODEL_NAME"
		--tokenizer
		"$MODEL"
		--dataset-name
		"$DATASET_NAME"
		--num-prompts
		"$NUM_PROMPTS"
		--random-input-len
		"$INPUT_LEN"
		--random-output-len
		"$OUTPUT_LEN"
		--percentile-metrics
		"ttft,tpot,itl,e2el"
	)
	if [[ -n "${MAX_CONCURRENCY:-}" ]]; then
		args+=(--max-concurrency "$MAX_CONCURRENCY")
	else
		args+=(--request-rate "$REQUEST_RATE")
	fi
	printf '%s\n' "${args[@]}"
}

ops_bench_run_native() {
	local -a args=()
	mapfile -t args < <(ops_bench_cmd_args)
	# drop leading "bench serve" → vllm bench serve
	vllm "${args[@]}"
}

ops_bench_run_docker() {
	local entry=()
	[[ "${1:-}" == "entrypoint" ]] && entry=(--entrypoint vllm)
	local -a args=()
	mapfile -t args < <(ops_bench_cmd_args)
	docker run --rm --network host \
		"${entry[@]}" \
		-e OPENAI_API_KEY="${VLLM_API_KEY}" \
		-e VLLM_API_KEY="${VLLM_API_KEY}" \
		-e HF_TOKEN="${HF_TOKEN:-}" \
		-e HUGGING_FACE_HUB_TOKEN="${HF_TOKEN:-}" \
		-v "${HF_CACHE}:/root/.cache/huggingface" \
		"${VLLM_IMAGE:-$IMAGE}" \
		"${args[@]}"
}

# Prefer native vllm; else docker image. Writes REPORT_FILE.
ops_bench_execute() {
	local report="${1:?report file}"
	local rc=0
	export OPENAI_API_KEY="${VLLM_API_KEY}"
	mkdir -p "$(dirname "$report")"
	echo "=== benchmark ==="
	echo "Workload: prompts=${NUM_PROMPTS} input=${INPUT_LEN} output=${OUTPUT_LEN} rate=${REQUEST_RATE}${MAX_CONCURRENCY:+ conc=$MAX_CONCURRENCY}"
	echo "Report:   ${report}"
	set +e
	if command -v vllm >/dev/null 2>&1; then
		ops_bench_run_native 2>&1 | tee "$report"
		rc=${PIPESTATUS[0]}
	else
		ops_bench_run_docker 2>&1 | tee "$report"
		rc=${PIPESTATUS[0]}
		if [[ $rc -ne 0 ]]; then
			ops_bench_run_docker entrypoint 2>&1 | tee -a "$report"
			rc=${PIPESTATUS[0]}
		fi
	fi
	set -e
	if [[ $rc -eq 0 ]]; then
		echo "STATUS: PASS"
		echo "RESULT: PASS"
		echo "Saved: $report"
		return 0
	fi
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (rc=$rc)"
	echo "See: $report" >&2
	return "$rc"
}

ops_bench_load_run() {
	local rates_csv="${BENCH_RATES:-1,4,8}"
	local rate stamp dir summary
	stamp="$(date -u +%Y%m%dT%H%M%SZ)"
	dir="${BENCH_DIR}/load-${stamp}"
	mkdir -p "$dir"
	summary="${dir}/summary.txt"
	echo "=== benchmark-load ===" | tee "$summary"
	echo "Rates: ${rates_csv}" | tee -a "$summary"
	echo "Base workload: prompts=${NUM_PROMPTS} in=${INPUT_LEN} out=${OUTPUT_LEN}" | tee -a "$summary"
	echo | tee -a "$summary"

	local IFS=','
	# shellcheck disable=SC2086
	set -- ${rates_csv}
	unset IFS
	local any_fail=0
	for rate in "$@"; do
		rate="$(echo "$rate" | tr -d '[:space:]')"
		[[ -n "$rate" ]] || continue
		REQUEST_RATE="$rate"
		MAX_CONCURRENCY=""
		local report="${dir}/rate-${rate}.txt"
		echo "--- request-rate=${rate} ---" | tee -a "$summary"
		if ops_bench_execute "$report"; then
			# Extract key lines if present
			{
				echo "rate=${rate} RESULT=PASS"
				rg -n 'Request throughput|Output token throughput|Median TTFT|P99 TTFT|Median TPOT|P99 TPOT|Failed requests|Benchmark complete' "$report" 2>/dev/null ||
					grep -nEi 'throughput|TTFT|TPOT|Failed|complete' "$report" | head -40 || true
			} | tee -a "$summary"
		else
			any_fail=1
			echo "rate=${rate} RESULT=FAIL" | tee -a "$summary"
		fi
		echo | tee -a "$summary"
	done

	echo "Summary: $summary"
	if [[ "$any_fail" -eq 0 ]]; then
		echo "STATUS: PASS"
		echo "RESULT: PASS"
		return 0
	fi
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (one or more rates failed)"
	return 1
}
