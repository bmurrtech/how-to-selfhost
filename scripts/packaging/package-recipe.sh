#!/usr/bin/env bash
# Build a deterministic recipe tarball + sha256 for GitHub Releases.
# Usage: bash scripts/packaging/package-recipe.sh [version]
# Default version: 0.0.1-rc1
# Output: dist/packaging/<artifact>.tar.gz and .sha256
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="${1:-0.0.1-rc1}"
FAMILY="qwen3-8-flash-next"
TARGET="spark"
RECIPE_ID="${FAMILY}/${TARGET}"
ARTIFACT="${FAMILY}-${TARGET}-${VERSION}.tar.gz"
OUT_DIR="${ROOT}/dist/packaging"
STAGE="${OUT_DIR}/stage-${FAMILY}-${TARGET}-${VERSION}"
SRC_LOCAL_AI="${ROOT}/scripts/local-ai"

if [[ ! -d "${SRC_LOCAL_AI}/recipes/${FAMILY}/${TARGET}" ]]; then
	echo "error: missing recipe tree scripts/local-ai/recipes/${FAMILY}/${TARGET}" >&2
	exit 1
fi

rm -rf "${STAGE}"
mkdir -p "${STAGE}/local-ai" "${OUT_DIR}"

# Copy via tar so we do not depend on rsync; exclude secrets/weights/cache.
tar -C "${SRC_LOCAL_AI}" \
	--exclude='.env' \
	--exclude='.env.*' \
	--exclude='./.env' \
	--exclude='**/.runtime.env' \
	--exclude='**/.runtime.env.*' \
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
	-cf - . | tar -C "${STAGE}/local-ai" -xf -

# Restore tracked example if exclude patterns dropped it.
if [[ -f "${SRC_LOCAL_AI}/.env.example" ]]; then
	cp -f "${SRC_LOCAL_AI}/.env.example" "${STAGE}/local-ai/.env.example"
fi

# Safety: refuse if a real .env slipped in.
if find "${STAGE}" \( -name '.env' -o -name '.runtime.env' \) | grep -q .; then
	echo "error: refusing to pack; secret env file present in stage" >&2
	find "${STAGE}" \( -name '.env' -o -name '.runtime.env' \) -print >&2
	exit 1
fi

cat >"${STAGE}/local-ai/ARTIFACT.txt" <<EOF
recipe_id=${RECIPE_ID}
version=${VERSION}
source=scripts/local-ai
EOF

tar -C "${STAGE}" -czf "${OUT_DIR}/${ARTIFACT}" local-ai

if command -v sha256sum >/dev/null 2>&1; then
	(cd "${OUT_DIR}" && sha256sum "${ARTIFACT}" >"${ARTIFACT}.sha256")
elif command -v shasum >/dev/null 2>&1; then
	(cd "${OUT_DIR}" && shasum -a 256 "${ARTIFACT}" | awk '{print $1"  "$2}' >"${ARTIFACT}.sha256")
else
	echo "error: need sha256sum or shasum" >&2
	exit 1
fi

echo "wrote ${OUT_DIR}/${ARTIFACT}"
echo "wrote ${OUT_DIR}/${ARTIFACT}.sha256"
cat "${OUT_DIR}/${ARTIFACT}.sha256"
echo
TAG="v${VERSION}"
echo "Next (HUMAN):"
echo "  1. Inspect tarball (no .env / weights / caches): tar -tzf ${OUT_DIR}/${ARTIFACT} | less"
echo "  2. gh release create ${TAG} ${OUT_DIR}/${ARTIFACT} ${OUT_DIR}/${ARTIFACT}.sha256 --prerelease --title ${TAG} --notes 'First rc for ${RECIPE_ID}'"
echo "  3. Paste sha256 into catalog/recipes.json for ${RECIPE_ID} @ ${VERSION}"
echo "  4. Confirm catalog url uses .../releases/download/${TAG}/${ARTIFACT}"
echo "  5. Commit catalog update on main (immutable: never replace ${TAG} assets)"
