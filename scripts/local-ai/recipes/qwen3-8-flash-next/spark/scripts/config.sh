#!/usr/bin/env bash
# config.sh — ensure .env + print resolved serve config (no secrets).
#   just config --show  — resolved only (no ensure / no prompts)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/ops_common.sh
source "${LIB_DIR}/ops_common.sh"

SHOW_ONLY=0
case "${1:-}" in
--show | show)
	SHOW_ONLY=1
	shift || true
	;;
esac

if [[ "$SHOW_ONLY" -eq 1 ]]; then
	if [[ -f "$RUNTIME_ENV" ]]; then
		# shellcheck disable=SC1090
		set -a
		# shellcheck source=/dev/null
		source "$RUNTIME_ENV"
		set +a
	fi
	ops_config_show "$RUNTIME_ENV" "docker"
	exit 0
fi

config_env_ensure

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Resolve without requiring API key for display; strip secrets from output.
if [[ -z "${VLLM_API_KEY:-}" ]]; then
	VLLM_API_KEY="__redacted__"
	export VLLM_API_KEY
fi

if resolve_serve_write "$tmp" >/dev/null 2>&1; then
	# shellcheck disable=SC1090
	set -a
	# shellcheck source=/dev/null
	source "$tmp"
	set +a
fi

echo
ops_config_show "${RUNTIME_ENV:-$tmp}" "docker"

if [[ -f "$RUNTIME_ENV" ]]; then
	echo
	echo "Active .runtime.env CONFIG_HASH=$(grep -E '^CONFIG_HASH=' "$RUNTIME_ENV" | cut -d= -f2- | cut -c1-12)…"
fi

echo
echo "Retrieve API key deliberately: just token"
echo "Show only: just config --show"
