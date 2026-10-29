#!/usr/bin/env bash
# Read-only preflight for patching/* (bootstrap runs this after extract).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "patching / check"
echo "root=$ROOT"

need=(
	Update-DevTools.ps1
	update-devtools.sh
	update-config.json
	Patching.Lib.ps1
	README.md
	.mycmd-extract-only
)

for f in "${need[@]}"; do
	if [[ ! -f "$ROOT/$f" ]]; then
		echo "FAIL: missing $f" >&2
		exit 1
	fi
	echo "ok: $f"
done

if [[ ! -x "$ROOT/update-devtools.sh" ]]; then
	chmod +x "$ROOT/update-devtools.sh" || true
fi

echo "patching check: ok"
