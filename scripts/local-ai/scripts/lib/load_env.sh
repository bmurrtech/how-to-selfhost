#!/usr/bin/env bash
# load_env.sh — load recipe serve.env then scripts/local-ai/.env.
# Precedence: recipe defaults < .env < already-set *non-empty* shell exports.
# Blank KEY= lines are ignored (never clobber a Secret / injected env).
#
# Usage:
#   source "${ROOT_DIR}/scripts/lib/load_env.sh"
#   local_ai_load_env "$RECIPE_DIR"
#   local_ai_resolve_hf_token   # optional; also called from recipe_bootstrap

local_ai_root() {
	local here
	here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "${here}/../.." && pwd
}

local_ai_env_path() {
	echo "$(local_ai_root)/.env"
}

# True when value looks like unresolved RunPod Secret interpolation.
_local_ai_hf_token_is_placeholder() {
	local v="${1:-}"
	[[ -z "$v" ]] && return 1
	[[ "$v" == *"{{"* && "$v" == *"}}"* ]] && return 0
	return 1
}

# Resolve HF auth without printing token values.
# Prefer non-empty process env (HF_TOKEN → HUGGING_FACE_HUB_TOKEN → RUNPOD_SECRET_HF_TOKEN),
# then non-empty .env. Never copy env/Secret into .env here.
# Sets CONFIG_ENV_HF_SOURCE when empty: environment | dotenv | absent
local_ai_resolve_hf_token() {
	local token="" src="absent" env_file line key val

	if [[ -n "${HF_TOKEN:-}" ]] && ! _local_ai_hf_token_is_placeholder "${HF_TOKEN}"; then
		token="${HF_TOKEN}"
		src=environment
	elif [[ -n "${HUGGING_FACE_HUB_TOKEN:-}" ]] && ! _local_ai_hf_token_is_placeholder "${HUGGING_FACE_HUB_TOKEN}"; then
		token="${HUGGING_FACE_HUB_TOKEN}"
		src=environment
	elif [[ -n "${RUNPOD_SECRET_HF_TOKEN:-}" ]] && ! _local_ai_hf_token_is_placeholder "${RUNPOD_SECRET_HF_TOKEN}"; then
		token="${RUNPOD_SECRET_HF_TOKEN}"
		src=environment
	else
		env_file="$(local_ai_env_path)"
		if [[ -f "$env_file" ]]; then
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
				case "$key" in
				HF_TOKEN | HUGGING_FACE_HUB_TOKEN) ;;
				*) continue ;;
				esac
				val="${line#*=}"
				if [[ "$val" =~ ^\".*\"$ ]]; then
					val="${val:1:${#val}-2}"
				elif [[ "$val" =~ ^\'.*\'$ ]]; then
					val="${val:1:${#val}-2}"
				fi
				[[ -z "$val" ]] && continue
				_local_ai_hf_token_is_placeholder "$val" && continue
				token="$val"
				src=dotenv
				break
			done <"$env_file"
		fi
	fi

	if _local_ai_hf_token_is_placeholder "${HF_TOKEN:-}" ||
		_local_ai_hf_token_is_placeholder "${HUGGING_FACE_HUB_TOKEN:-}"; then
		echo "warn: HF token looks like unresolved {{ RUNPOD_SECRET_… }} — check Secrets attach" >&2
		unset HF_TOKEN HUGGING_FACE_HUB_TOKEN || true
		token=""
		src=absent
	fi

	if [[ -n "$token" ]]; then
		export HF_TOKEN="$token"
		export HUGGING_FACE_HUB_TOKEN="$token"
	fi
	CONFIG_ENV_HF_SOURCE="$src"
	export CONFIG_ENV_HF_SOURCE
}

# Apply KEY=VALUE lines from a file. Keys present in the nameref map `preset` are skipped
# (non-empty shell-pre-set protection). Keys not in preset are set/overwritten.
# Blank values are never applied.
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
		[[ -n "$key" ]] || continue
		# Protect only non-empty exports so blank HF_TOKEN= in the process (or a
		# previously sourced empty .env) cannot block a real Secret / dotenv value.
		# shellcheck disable=SC2034 # filled for nameref in _local_ai_apply_env_file
		if [[ -n "${!key:-}" ]]; then
			preset["$key"]=1
		fi
	done < <(compgen -e)

	if [[ -n "$recipe_dir" && -f "${recipe_dir}/config/serve.env" ]]; then
		_local_ai_apply_env_file "${recipe_dir}/config/serve.env" preset
	fi
	_local_ai_apply_env_file "$(local_ai_env_path)" preset
	local_ai_resolve_hf_token
}
