#!/usr/bin/env bash
# setup.sh — prepare RTX PRO 6000 (Docker path or native-in-vLLM path).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../../scripts/lib/recipe_common.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/recipe_common.sh"
recipe_bootstrap
# shellcheck source=../../../../scripts/lib/rtx_serve.sh
source "${LIB_DIR}/rtx_serve.sh"
# shellcheck source=../../../../scripts/lib/docker_nct.sh
source "${LIB_DIR}/docker_nct.sh"

rtx_prefer_volume_cache
mode="$(rtx_detect_exec_mode)"

echo "=== setup: qwen3-8-flash-next / rtx-6000-pro (mode=${mode}) ==="

mkdir -p "$HF_CACHE" "${HOME}/models" "$BENCH_DIR" "${RECIPE_DIR}/.run"
CONFIG_PROMPT_HF_TOKEN=0
export CONFIG_PROMPT_HF_TOKEN
config_env_ensure
unset CONFIG_PROMPT_HF_TOKEN

detected="$(rtx_gpu_count)"
count="$(rtx_interactive_select "$RECIPE_DIR" "$detected")"
echo "profile: gpu-${count} (${PROFILE_STATUS:-unknown})"
if [[ -n "${VLLM_CACHE_ROOT:-}" ]]; then
	mkdir -p "${VLLM_CACHE_ROOT}"
fi

if [[ "$mode" == "docker" ]]; then
	echo "--- Docker / NCT ---"
	docker_nct_install_docker
	docker_nct_install_nct
else
	echo "--- native mode: skip Docker/NCT/CUDA host install ---"
	if ! rtx_vllm_present; then
		echo "FAILED: native mode requires vllm on PATH (image vllm/vllm-openai:qwen38-flash-next)" >&2
		exit 1
	fi
fi

echo "--- weights ---"
if [[ "${FORCE_DOWNLOAD:-0}" != "1" ]] && weights_complete; then
	pacman_progress_done "skip download (weights present)"
else
	if [[ "$mode" == "native" ]]; then
		dl=run_download_native
	else
		dl=run_download
	fi
	if "$dl" && weights_complete; then
		pacman_progress_done "weights ready"
	else
		echo "FAILED: weights incomplete" >&2
		exit 1
	fi
fi

if [[ "$mode" == "docker" ]]; then
	echo "--- image $IMAGE ---"
	if docker image inspect "$IMAGE" >/dev/null 2>&1 && [[ "${FORCE_PULL:-0}" != "1" ]]; then
		echo "skip: image present"
	else
		pacman_phase 40 "docker pull $IMAGE"
		docker pull "$IMAGE"
		pacman_progress_done "pulled"
	fi
	docker image inspect -f '{{.Id}} {{json .RepoDigests}}' "$IMAGE" || true
fi

rtx_resolve_write "$RUNTIME_ENV"
echo
echo "setup complete (mode=${mode}). Next: just deploy"
if [[ "$mode" == "native" ]]; then
	echo "Tip: RunPod Start CMD must override entrypoint+cmd (JSON sleep) so this recipe owns vllm serve — see README."
fi
