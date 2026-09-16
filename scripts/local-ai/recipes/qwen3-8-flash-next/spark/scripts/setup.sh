#!/usr/bin/env bash
# setup.sh — converge dirs, weights, pinned PLE mmap image (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap

echo "=== setup: qwen3-8-flash-next / spark ==="

# dirs + secrets
mkdir -p "$HF_CACHE" "${HOME}/models" "$BENCH_DIR"
CONFIG_PROMPT_HF_TOKEN=0
export CONFIG_PROMPT_HF_TOKEN
config_env_ensure
unset CONFIG_PROMPT_HF_TOKEN

# weights
echo "--- weights ---"
if [[ "${FORCE_DOWNLOAD:-0}" != "1" ]] && weights_complete; then
	pacman_progress_done "skip download (weights present)"
else
	if run_download && weights_complete; then
		pacman_progress_done "weights ready"
	else
		echo "FAILED: weights incomplete after retries" >&2
		exit 1
	fi
fi

# clone + build pinned community image
echo "--- image $IMAGE ---"
cmd_clone() {
	if [[ -d "${FLASH_DGX_DIR}/.git" ]]; then
		local have
		have="$(git -C "$FLASH_DGX_DIR" rev-parse HEAD)"
		if [[ "$have" == "$FLASH_REPO_REF" ]]; then
			echo "skip: clone already at $FLASH_REPO_REF"
			return 0
		fi
		echo "checkout pinned ref $FLASH_REPO_REF (was $have)"
		git -C "$FLASH_DGX_DIR" fetch --depth 1 origin "$FLASH_REPO_REF"
		git -C "$FLASH_DGX_DIR" checkout --detach "$FLASH_REPO_REF"
		return 0
	fi
	pacman_phase 10 "clone blazux/qwen3.8-Flash-DGX @$FLASH_REPO_REF"
	git clone --depth 1 "$FLASH_REPO_URL" "$FLASH_DGX_DIR"
	git -C "$FLASH_DGX_DIR" fetch --depth 1 origin "$FLASH_REPO_REF"
	git -C "$FLASH_DGX_DIR" checkout --detach "$FLASH_REPO_REF"
	pacman_progress_done "cloned"
}

if docker image inspect "$IMAGE" >/dev/null 2>&1 && [[ "${FORCE_BUILD:-0}" != "1" ]]; then
	echo "skip: image $IMAGE present"
	docker image inspect -f '{{.Id}} qwen38.base={{index .Config.Labels "qwen38.base"}}' "$IMAGE"
else
	cmd_clone
	pacman_phase 40 "docker build $IMAGE"
	docker build --pull=false -t "$IMAGE" -t "qwen38-flash-dgx:latest" "$FLASH_DGX_DIR"
	pacman_progress_done "image built"
	docker image inspect -f '{{.Id}} qwen38.base={{index .Config.Labels "qwen38.base"}}' "$IMAGE"
fi

echo
echo "setup complete."
echo "Next: just deploy"
