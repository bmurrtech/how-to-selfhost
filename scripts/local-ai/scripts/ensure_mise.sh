#!/usr/bin/env bash
# ensure_mise.sh — install mise when missing (operator toolchain only).
# Does NOT install NVIDIA/CUDA/vLLM/weights. Safe to re-run.
set -euo pipefail

MISE_INSTALL_URL="${MISE_INSTALL_URL:-https://mise.run}"
# Common install locations before PATH is updated.
export PATH="${HOME}/.local/bin:${HOME}/.mise/bin:${PATH}"

if command -v mise >/dev/null 2>&1; then
	exit 0
fi

echo "mycmd: mise not found — attempting install via ${MISE_INSTALL_URL}"

install_rc=1
if command -v curl >/dev/null 2>&1; then
	set +e
	curl -fsSL "${MISE_INSTALL_URL}" | sh
	install_rc=$?
	set -e
elif command -v wget >/dev/null 2>&1; then
	set +e
	wget -qO- "${MISE_INSTALL_URL}" | sh
	install_rc=$?
	set -e
else
	echo "mycmd: curl or wget required to install mise" >&2
	install_rc=1
fi

export PATH="${HOME}/.local/bin:${HOME}/.mise/bin:${PATH}"
if [[ "$install_rc" -eq 0 ]] && command -v mise >/dev/null 2>&1; then
	echo "mycmd: mise ready → $(command -v mise)"
	exit 0
fi

echo "mycmd: could not auto-install mise (network/policy/offline?)." >&2
echo "mycmd: install manually, then re-run from the recipe directory:" >&2
echo "  curl -fsSL https://mise.run | sh" >&2
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
echo "  mise install" >&2
exit 1
