#!/usr/bin/env bash
# docker_nct.sh — idempotent Docker Engine + NVIDIA Container Toolkit helpers (metal).
# shellcheck shell=bash
#
# Does NOT install NVIDIA drivers. Aborts on non-Ubuntu or unsupported VERSION_ID.

docker_nct_require_ubuntu() {
	if [[ ! -f /etc/os-release ]]; then
		echo "error: /etc/os-release missing" >&2
		return 1
	fi
	# shellcheck disable=SC1091
	. /etc/os-release
	if [[ "${ID:-}" != "ubuntu" ]]; then
		echo "error: Docker install path expects Ubuntu (got ID=${ID:-unknown})" >&2
		return 1
	fi
	case "${VERSION_ID:-}" in
	22.04 | 24.04) ;;
	*)
		echo "error: unsupported Ubuntu ${VERSION_ID:-}; need 22.04 or 24.04 for Docker install" >&2
		return 1
		;;
	esac
	export UBUNTU_CODENAME="${VERSION_CODENAME:-}"
	export UBUNTU_VERSION_ID="$VERSION_ID"
}

docker_engine_ok() {
	command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

docker_compose_ok() {
	docker compose version >/dev/null 2>&1
}

nvidia_ctk_ok() {
	command -v nvidia-ctk >/dev/null 2>&1 || docker info 2>/dev/null | grep -qi nvidia
}

# Install Docker Engine via Ubuntu docker.com apt repo (conservative, idempotent).
docker_nct_install_docker() {
	docker_nct_require_ubuntu || return 1
	if docker_engine_ok && docker_compose_ok; then
		echo "skip: Docker Engine + Compose already usable"
		return 0
	fi
	echo "Installing Docker Engine (official Ubuntu apt repo)…"
	sudo apt-get update -y
	sudo apt-get install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
		sudo chmod a+r /etc/apt/keyrings/docker.asc
	fi
	# shellcheck disable=SC1091
	. /etc/os-release
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" |
		sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update -y
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo systemctl enable --now docker
	if [[ -n "${SUDO_USER:-}" ]]; then
		sudo usermod -aG docker "$SUDO_USER" || true
		echo "NOTE: log out/in (or newgrp docker) so $SUDO_USER can run docker without sudo"
	elif [[ "$(id -u)" -ne 0 ]]; then
		sudo usermod -aG docker "$(id -un)" || true
	fi
}

# Install NVIDIA Container Toolkit when missing.
docker_nct_install_nct() {
	docker_nct_require_ubuntu || return 1
	if nvidia_ctk_ok && docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
		echo "skip: NVIDIA Container Toolkit / GPU passthrough OK"
		return 0
	fi
	echo "Installing NVIDIA Container Toolkit…"
	curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |
		sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
	curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
		sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
		sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
	sudo apt-get update -y
	sudo apt-get install -y nvidia-container-toolkit
	sudo nvidia-ctk runtime configure --runtime=docker
	sudo systemctl restart docker
}
