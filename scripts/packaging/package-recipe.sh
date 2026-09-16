#!/usr/bin/env bash
# Build a deterministic recipe tarball + sha256 for GitHub Releases.
# Usage:
#   bash scripts/packaging/package-recipe.sh [version]
#   bash scripts/packaging/package-recipe.sh <recipe_id> [version]
#   bash scripts/packaging/package-recipe.sh --recipe <id> [--version <ver>]
#
# Default recipe: qwen3-8-flash-next/spark
# Default version: 0.0.1-rc2
#
# Supported recipe IDs:
#   qwen3-8-flash-next/spark
#   qwen3-8-flash-next/rtx-6000-pro
#   security/vps-baseline
#
# Output: dist/packaging/<artifact>.tar.gz and .sha256
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_VERSION="0.0.1-rc2"
DEFAULT_RECIPE="qwen3-8-flash-next/spark"

RECIPE_ID=""
VERSION=""

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--recipe)
		RECIPE_ID="${2:?}"
		shift 2
		;;
	--version)
		VERSION="${2:?}"
		shift 2
		;;
	-h | --help)
		usage
		;;
	--*)
		echo "error: unknown flag $1" >&2
		usage
		;;
	*)
		if [[ -z "$RECIPE_ID" && "$1" == */* ]]; then
			RECIPE_ID="$1"
		elif [[ -z "$VERSION" ]]; then
			VERSION="$1"
		else
			echo "error: unexpected arg: $1" >&2
			usage
		fi
		shift
		;;
	esac
done

RECIPE_ID="${RECIPE_ID:-$DEFAULT_RECIPE}"
VERSION="${VERSION:-$DEFAULT_VERSION}"

OUT_DIR="${ROOT}/dist/packaging"

compose_name_for() {
	case "$1" in
	qwen3-8-flash-next/spark) echo "qwen38-spark" ;;
	qwen3-8-flash-next/rtx-6000-pro) echo "qwen38-rtx" ;;
	*) echo "" ;;
	esac
}

rewrite_justfile() {
	local stage_root="$1" recipe_id="$2" compose_name="$3"
	local justfile="${stage_root}/Justfile"
	cat >"$justfile" <<EOF
# Packaged default recipe: ${recipe_id}
set dotenv-load := false

RECIPE := env_var_or_default("RECIPE", "recipes/${recipe_id}")
export COMPOSE_PROJECT_NAME := env_var_or_default("COMPOSE_PROJECT_NAME", "${compose_name}")

default:
	@just --list

doctor:
	bash {{RECIPE}}/scripts/doctor.sh

check:
	bash {{RECIPE}}/scripts/doctor.sh

config *ARGS:
	bash {{RECIPE}}/scripts/config.sh {{ARGS}}

probe:
	bash {{RECIPE}}/scripts/probe.sh

benchmark *ARGS:
	bash {{RECIPE}}/scripts/benchmark.sh {{ARGS}}

benchmark-load *ARGS:
	bash {{RECIPE}}/scripts/benchmark-load.sh {{ARGS}}

gpu *ARGS:
	bash {{RECIPE}}/scripts/gpu.sh {{ARGS}}

gpu-watch:
	bash {{RECIPE}}/scripts/gpu.sh --watch

logs *ARGS:
	bash {{RECIPE}}/scripts/logs.sh {{ARGS}}

snapshot:
	bash {{RECIPE}}/scripts/snapshot.sh

setup:
	bash {{RECIPE}}/scripts/setup.sh

deploy:
	bash {{RECIPE}}/scripts/deploy.sh

status:
	bash {{RECIPE}}/scripts/status.sh

stop:
	bash {{RECIPE}}/scripts/stop.sh

token:
	bash {{RECIPE}}/scripts/token.sh
EOF
}

sha256_file() {
	local dir="$1" artifact="$2"
	if command -v sha256sum >/dev/null 2>&1; then
		(cd "$dir" && sha256sum "$artifact" >"${artifact}.sha256")
	elif command -v shasum >/dev/null 2>&1; then
		(cd "$dir" && shasum -a 256 "$artifact" | awk '{print $1"  "$2}' >"${artifact}.sha256")
	else
		echo "error: need sha256sum or shasum" >&2
		exit 1
	fi
}

pack_qwen_local_ai() {
	local recipe_id="$1" version="$2"
	local family target artifact stage src_local_ai compose_name keep
	family="${recipe_id%%/*}"
	target="${recipe_id#*/}"
	artifact="${family}-${target}-${version}.tar.gz"
	stage="${OUT_DIR}/stage-${family}-${target}-${version}"
	src_local_ai="${ROOT}/scripts/local-ai"
	compose_name="$(compose_name_for "$recipe_id")"
	keep="${src_local_ai}/recipes/${family}/${target}"

	if [[ ! -d "$keep" ]]; then
		echo "error: missing recipe tree scripts/local-ai/recipes/${family}/${target}" >&2
		exit 1
	fi
	if [[ -z "$compose_name" ]]; then
		echo "error: no COMPOSE_PROJECT_NAME mapping for ${recipe_id}" >&2
		exit 1
	fi

	rm -rf "${stage}"
	mkdir -p "${stage}/local-ai" "${OUT_DIR}"

	# Copy via tar so we do not depend on rsync; exclude secrets/weights/cache.
	tar -C "${src_local_ai}" \
		--exclude='.env' \
		--exclude='.env.*' \
		--exclude='./.env' \
		--exclude='**/.runtime.env' \
		--exclude='**/.runtime.env.*' \
		--exclude='**/.run' \
		--exclude='.git' \
		--exclude='node_modules' \
		--exclude='.cache' \
		--exclude='__pycache__' \
		--exclude='mise.lock' \
		--exclude='models' \
		--exclude='hosts' \
		--exclude='infrastructure' \
		--exclude='topologies' \
		--exclude='runtimes' \
		--exclude='schemas' \
		--exclude='scripts/distribution' \
		--exclude='scripts/packaging' \
		-cf - . | tar -C "${stage}/local-ai" -xf -

	# Restore tracked example if exclude patterns dropped it.
	if [[ -f "${src_local_ai}/.env.example" ]]; then
		cp -f "${src_local_ai}/.env.example" "${stage}/local-ai/.env.example"
	fi

	# Strip sibling recipes — keep only this family/target.
	if [[ -d "${stage}/local-ai/recipes" ]]; then
		find "${stage}/local-ai/recipes" -mindepth 2 -maxdepth 2 -type d | while read -r d; do
			case "$d" in
			*/recipes/"${family}/${target}") ;;
			*) rm -rf "$d" ;;
			esac
		done
		# Drop empty family dirs
		find "${stage}/local-ai/recipes" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
	fi

	rewrite_justfile "${stage}/local-ai" "${recipe_id}" "${compose_name}"

	# Safety: refuse if a real .env slipped in.
	if find "${stage}" \( -name '.env' -o -name '.runtime.env' \) | grep -q .; then
		echo "error: refusing to pack; secret env file present in stage" >&2
		find "${stage}" \( -name '.env' -o -name '.runtime.env' \) -print >&2
		exit 1
	fi

	cat >"${stage}/local-ai/ARTIFACT.txt" <<EOF
recipe_id=${recipe_id}
version=${version}
source=scripts/local-ai
EOF

	tar -C "${stage}" -czf "${OUT_DIR}/${artifact}" local-ai
	sha256_file "${OUT_DIR}" "${artifact}"

	echo "wrote ${OUT_DIR}/${artifact}"
	echo "wrote ${OUT_DIR}/${artifact}.sha256"
	cat "${OUT_DIR}/${artifact}.sha256"
	echo
	local tag="v${version}"
	echo "Next (HUMAN):"
	echo "  1. Inspect tarball (no .env / weights / caches): tar -tzf ${OUT_DIR}/${artifact} | less"
	echo "  2. gh release create ${tag} ${OUT_DIR}/${artifact} ${OUT_DIR}/${artifact}.sha256 --prerelease --title ${tag} --notes 'rc for ${recipe_id}'"
	echo "  3. Paste sha256 into catalog/recipes.json for ${recipe_id} @ ${version}"
	echo "  4. Confirm catalog url uses .../releases/download/${tag}/${artifact}"
	echo "  5. Commit catalog update on main (immutable: never replace ${tag} assets)"
}

pack_security_vps() {
	local recipe_id="$1" version="$2"
	local artifact stage src
	artifact="security-vps-baseline-${version}.tar.gz"
	stage="${OUT_DIR}/stage-security-vps-baseline-${version}"
	src="${ROOT}/scripts/security"

	if [[ ! -d "$src" ]]; then
		echo "error: missing scripts/security" >&2
		exit 1
	fi

	rm -rf "${stage}"
	mkdir -p "${stage}/security" "${OUT_DIR}"

	tar -C "${src}" \
		--exclude='archive' \
		--exclude='.env' \
		--exclude='.git' \
		--exclude='node_modules' \
		--exclude='__pycache__' \
		-cf - . | tar -C "${stage}/security" -xf -

	if find "${stage}" -name '.env' | grep -q .; then
		echo "error: refusing to pack; .env present in stage" >&2
		exit 1
	fi

	cat >"${stage}/security/ARTIFACT.txt" <<EOF
recipe_id=${recipe_id}
version=${version}
source=scripts/security
EOF

	tar -C "${stage}" -czf "${OUT_DIR}/${artifact}" security
	sha256_file "${OUT_DIR}" "${artifact}"

	echo "wrote ${OUT_DIR}/${artifact}"
	echo "wrote ${OUT_DIR}/${artifact}.sha256"
	cat "${OUT_DIR}/${artifact}.sha256"
	echo
	local tag="security-vps-baseline-v${version}"
	echo "Next (HUMAN):"
	echo "  1. Inspect: tar -tzf ${OUT_DIR}/${artifact} | less"
	echo "  2. gh release create ${tag} ${OUT_DIR}/${artifact} ${OUT_DIR}/${artifact}.sha256 --prerelease --title ${tag}"
	echo "  3. Paste sha256 into catalog/recipes.json for ${recipe_id} @ ${version}"
}

case "$RECIPE_ID" in
qwen3-8-flash-next/spark | qwen3-8-flash-next/rtx-6000-pro)
	pack_qwen_local_ai "$RECIPE_ID" "$VERSION"
	;;
security/vps-baseline)
	pack_security_vps "$RECIPE_ID" "$VERSION"
	;;
*)
	echo "error: unsupported recipe_id: ${RECIPE_ID}" >&2
	echo "supported: qwen3-8-flash-next/{spark,rtx-6000-pro}, security/vps-baseline" >&2
	exit 1
	;;
esac
