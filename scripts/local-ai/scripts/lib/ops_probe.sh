#!/usr/bin/env bash
# ops_probe.sh — one deterministic OpenAI-compatible completion + latency.
# shellcheck shell=bash
#
# Usage after recipe_bootstrap + require_api_key:
#   source "${LIB_DIR}/ops_probe.sh"
#   ops_probe_run

ops_probe_run() {
	local base="${BASE_URL:-http://127.0.0.1:${PORT:-8000}}"
	local model="${SERVED_MODEL_NAME:-qwen3.8-flash-next}"
	local expect="${PROBE_EXPECT:-PONG}"
	local prompt="${PROBE_PROMPT:-Reply with exactly the word ${expect} and nothing else.}"
	local tmp code t0 t1 now total_ms ttft_ms="" gen_tokens=0 text="" line piece
	local http_err ok=0

	if [[ -z "${SERVED_MODEL_NAME:-}" && -f "${RUNTIME_ENV:-}" ]]; then
		SERVED_MODEL_NAME="$(grep -E '^SERVED_MODEL_NAME=' "$RUNTIME_ENV" | head -1 | cut -d= -f2- || true)"
		model="${SERVED_MODEL_NAME:-$model}"
	fi

	echo "=== probe ==="
	echo "Target:  ${base}"
	echo "Model:   ${model}"
	echo "Expect:  ${expect}"
	echo

	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' RETURN

	code="$(curl -sS -o /dev/null -w '%{http_code}' \
		-H "Authorization: Bearer ${VLLM_API_KEY}" \
		"${base}/v1/models" 2>/dev/null || true)"
	if [[ "$code" != "200" ]]; then
		echo "HTTP /v1/models:       ${code:-000}"
		echo "RESULT: FAIL (endpoint not healthy)"
		return 1
	fi
	echo "HTTP /v1/models:       200"

	# Streaming request: TTFT = time to first SSE data payload; total = full stream.
	# PROBE_ENABLE_THINKING=0 → chat_template_kwargs.enable_thinking=false (ThinkingCap / Qwen3).
	local body thinking="${PROBE_ENABLE_THINKING:-1}"
	if [[ "$thinking" == "0" ]]; then
		body="$(jq -nc \
			--arg m "$model" \
			--arg p "$prompt" \
			'{model:$m, messages:[{role:"user",content:$p}], max_tokens:32, temperature:0, stream:true, chat_template_kwargs:{enable_thinking:false}}')"
	else
		body="$(jq -nc \
			--arg m "$model" \
			--arg p "$prompt" \
			'{model:$m, messages:[{role:"user",content:$p}], max_tokens:16, temperature:0, stream:true}')"
	fi

	t0="$(date +%s%N)"
	set +e
	while IFS= read -r line || [[ -n "$line" ]]; do
		now="$(date +%s%N)"
		[[ "$line" != data:* ]] && continue
		line="${line#data:}"
		line="${line#"${line%%[![:space:]]*}"}"
		[[ "$line" == "[DONE]" ]] && break
		[[ -z "$line" ]] && continue
		http_err="$(printf '%s' "$line" | jq -r '.error.message // empty' 2>/dev/null || true)"
		if [[ -n "$http_err" ]]; then
			echo "API error:            ${http_err}"
			echo "STATUS: FAIL"
			echo "RESULT: FAIL (API error)"
			set -e
			return 1
		fi
		piece="$(printf '%s' "$line" | jq -r '.choices[0].delta.content // empty' 2>/dev/null || true)"
		# Reasoning-only models (ThinkingCap) may stream into reasoning_content first.
		if [[ -z "$piece" ]]; then
			piece="$(printf '%s' "$line" | jq -r '.choices[0].delta.reasoning_content // .choices[0].delta.reasoning // empty' 2>/dev/null || true)"
		fi
		if [[ -n "$piece" ]]; then
			# TTFT = first content token, not empty/role-only chunks
			if [[ -z "$ttft_ms" ]]; then
				ttft_ms=$(((now - t0) / 1000000))
			fi
			text+="$piece"
		fi
		# usage may appear on final chunk
		piece="$(printf '%s' "$line" | jq -r '.usage.completion_tokens // empty' 2>/dev/null || true)"
		[[ -n "$piece" && "$piece" != "null" ]] && gen_tokens="$piece"
	done < <(curl -sS -N \
		-H "Authorization: Bearer ${VLLM_API_KEY}" \
		-H "Content-Type: application/json" \
		-d "$body" \
		"${base}/v1/chat/completions" 2>"$tmp")
	code=$?
	set -e
	t1="$(date +%s%N)"
	total_ms=$(((t1 - t0) / 1000000))

	if [[ "$code" -ne 0 && -z "$text" ]]; then
		echo "HTTP chat stream:      curl rc=${code}"
		if declare -F ops_redact_stream >/dev/null 2>&1; then
			ops_redact_stream <"$tmp" 2>/dev/null | tail -5 || true
		fi
		echo "RESULT: FAIL (request error)"
		return 1
	fi

	# Fallback: mark unknown rather than wc -w (words ≠ tokens)
	if [[ "${gen_tokens}" -eq 0 && -n "$text" ]]; then
		gen_tokens="unknown"
	fi

	printf 'HTTP chat:            ok (stream)\n'
	printf 'TTFT_ms:              %s\n' "${ttft_ms:-n/a}"
	printf 'total_latency_ms:     %s\n' "$total_ms"
	printf 'completion_tokens:    %s\n' "$gen_tokens"
	printf 'response_preview:     %s\n' "$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-120)"

	if printf '%s' "$text" | grep -qiF "$expect"; then
		ok=1
	fi

	if [[ "$ok" -eq 1 ]]; then
		echo "expect_match:         yes (${expect})"
		echo "STATUS: PASS"
		echo "RESULT: PASS"
		return 0
	fi
	echo "expect_match:         no (wanted substring ${expect})"
	echo "STATUS: FAIL"
	echo "RESULT: FAIL (unexpected response)"
	return 1
}
