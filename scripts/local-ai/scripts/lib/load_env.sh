#!/usr/bin/env bash
# load_env.sh — load recipe serve.env then scripts/local-ai/.env.
# Precedence: recipe defaults < .env < already-set shell exports.
# Blank KEY= lines are ignored.
#
# Usage:
#   source "${ROOT_DIR}/scripts/lib/load_env.sh"
#   local_ai_load_env "$RECIPE_DIR"

local_ai_root() {
	local here
	here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "${here}/../.." && pwd
}

local_ai_env_path() {
	echo "$(local_ai_root)/.env"
}

# Apply KEY=VALUE lines from a file. Keys present in the nameref map `preset` are skipped
# (shell-pre-set protection). Keys not in preset are set/overwritten.
_local_ai_apply_env_file() {
	local env_file="$1"
	local -n _preset="$2"

	[[ -f "$env_file" ]] || return 0

	local line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
		if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+ ]]; then
			line="${line#*export }"
			line="${line#"${line%%[![:space:]]*}"}"
		fi
		[[ "$line" != *=* ]] && continue
		key="${line%%=*}"
		key="${key%"${key##*[![:space:]]}"}"
		key="${key#"${key%%[![:space:]]*}"}"
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		if [[ -n "${_preset[$key]+x}" ]]; then
			continue
		fi
		val="${line#*=}"
		if [[ "$val" =~ ^\".*\"$ ]]; then
			val="${val:1:${#val}-2}"
		elif [[ "$val" =~ ^\'.*\'$ ]]; then
			val="${val:1:${#val}-2}"
		fi
		[[ -z "$val" ]] && continue
		if [[ "$val" == ~/* ]]; then
			val="${HOME}/${val:2}"
		elif [[ "$val" == "~" ]]; then
			val="${HOME}"
		fi
		printf -v "$key" '%s' "$val"
		# shellcheck disable=SC2163
		export "$key"
	done <"$env_file"
}

# local_ai_load_env [recipe_dir]
local_ai_load_env() {
	local recipe_dir="${1:-${RECIPE_DIR:-}}"
	local -A preset=()
	local key

	while IFS= read -r key; do
		# shellcheck disable=SC2034 # filled for nameref in _local_ai_apply_env_file
		[[ -n "$key" ]] && preset["$key"]=1
	done < <(compgen -e)

	if [[ -n "$recipe_dir" && -f "${recipe_dir}/config/serve.env" ]]; then
		_local_ai_apply_env_file "${recipe_dir}/config/serve.env" preset
	fi
	_local_ai_apply_env_file "$(local_ai_env_path)" preset
}
