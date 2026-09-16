#!/usr/bin/env bash
# ops_logs.sh — filter existing docker/native logs (no logging subsystem).
# shellcheck shell=bash

ops_logs_source_docker() {
	local name="${1:?container}"
	local tailn="${2:-200}"
	docker logs --tail "$tailn" "$name" 2>&1
}

ops_logs_source_native() {
	local log_file="${1:?log}"
	local tailn="${2:-200}"
	[[ -f "$log_file" ]] || {
		echo "No log at $log_file" >&2
		return 1
	}
	tail -n "$tailn" "$log_file"
}

ops_logs_filter_pattern() {
	case "${1:-}" in
	error) printf '%s' 'error|exception|failed|fatal|traceback' ;;
	cuda) printf '%s' 'cuda|cublas|cudnn|nccl|nvml' ;;
	oom) printf '%s' 'out of memory|outofmemory|cuda out of memory|oomkilled|oom-kill|insufficient memory' ;;
	vllm) printf '%s' 'vllm|enginecore|llm_engine|asyncllm' ;;
	*) return 1 ;;
	esac
}

# Args: mode(docker|native) name_or_logfile [filter_or_tail]
ops_logs_run() {
	local mode="${1:?mode}"
	local target="${2:?target}"
	local arg="${3:-100}"
	local follow=0
	local filter=""
	local tailn=200
	local pat hits

	case "$arg" in
	-f | --follow)
		follow=1
		;;
	error | cuda | oom | vllm)
		filter="$arg"
		tailn=400
		;;
	'' | [0-9]*)
		tailn="${arg:-100}"
		;;
	*)
		echo "usage: just logs [error|cuda|oom|vllm|<N>|-f]" >&2
		return 2
		;;
	esac

	echo "=== logs (${mode}${filter:+ filter=$filter}) ==="

	if [[ "$follow" -eq 1 ]]; then
		if [[ "$mode" == "docker" ]]; then
			docker logs -f "$target"
		else
			[[ -f "$target" ]] || {
				echo "No log at $target" >&2
				return 1
			}
			tail -f "$target"
		fi
		return 0
	fi

	local raw
	raw="$(mktemp)"
	trap 'rm -f "$raw"' RETURN
	if [[ "$mode" == "docker" ]]; then
		ops_logs_source_docker "$target" "$tailn" >"$raw" || true
	else
		ops_logs_source_native "$target" "$tailn" >"$raw" || return 1
	fi

	if [[ -n "$filter" ]]; then
		pat="$(ops_logs_filter_pattern "$filter")"
		local filtered
		filtered="$(mktemp)"
		if declare -F ops_redact_stream >/dev/null 2>&1; then
			ops_redact_stream <"$raw" >"$filtered"
		else
			cp "$raw" "$filtered"
		fi
		if command -v rg >/dev/null 2>&1; then
			rg -ni "$pat" "$filtered" || true
			hits="$(rg -ci "$pat" "$filtered" 2>/dev/null || echo 0)"
		else
			grep -niE "$pat" "$filtered" || true
			hits="$(grep -ciE "$pat" "$filtered" 2>/dev/null || echo 0)"
		fi
		rm -f "$filtered"
		echo
		echo "STATUS: PASS (filter=${filter}, hits≈${hits})"
		echo "RESULT: PASS"
		return 0
	fi

	if declare -F ops_redact_stream >/dev/null 2>&1; then
		ops_redact_stream <"$raw"
	else
		cat "$raw"
	fi
	echo
	echo "STATUS: PASS"
	echo "RESULT: PASS"
}
