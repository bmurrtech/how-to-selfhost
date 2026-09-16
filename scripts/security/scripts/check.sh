#!/usr/bin/env bash
# check.sh — read-only preflight for security/vps-baseline (bootstrap runs this).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILS=0
WARNS=0

pass() { printf '[PASS] %-18s %s\n' "$1" "${2:-}"; }
warn() {
	printf '[WARN] %-18s %s\n' "$1" "${2:-}"
	WARNS=$((WARNS + 1))
}
fail() {
	printf '[FAIL] %-18s %s\n' "$1" "${2:-}"
	FAILS=$((FAILS + 1))
}

echo "security / vps-baseline"
echo

if [[ -f /etc/os-release ]]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	pass "OS" "${PRETTY_NAME:-${NAME:-linux} ${VERSION_ID:-}}"
else
	warn "OS" "no /etc/os-release"
fi

for f in new-sudo-user.sh vps-sec-harden.sh f2b-install.sh Justfile mise.toml; do
	if [[ -f "$f" ]]; then
		pass "File:$f" "present"
	else
		fail "File:$f" "missing"
	fi
done

for t in just shellcheck shfmt; do
	if command -v "$t" >/dev/null 2>&1; then
		pass "Tool:$t" "$(command -v "$t")"
	else
		warn "Tool:$t" "missing (run: mise install)"
	fi
done

if command -v sudo >/dev/null 2>&1; then
	pass "sudo" "$(command -v sudo)"
else
	warn "sudo" "not found (needed for just user / just f2b)"
fi

echo
if [[ "$FAILS" -gt 0 ]]; then
	echo "NOT READY (${FAILS} fail, ${WARNS} warn)"
	echo
	echo "Next:"
	echo "  mise install"
	exit 1
fi

if [[ "$WARNS" -gt 0 ]]; then
	echo "READY WITH WARNINGS (${WARNS})"
else
	echo "READY"
fi
echo
echo "Next (fresh VPS order):"
echo "  just user     # optional; as root"
echo "  just harden   # as sudo user; keep a second SSH session open"
echo "  just f2b -- --whitelist <your-admin-ip>   # cloud; or just f2b on LAN"
echo "  just doctor"
exit 0
