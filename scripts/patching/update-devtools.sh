#!/usr/bin/env bash
# Update-only maintenance for already-installed macOS/Linux developer tools.
# Never installs missing apps or bootstraps package managers.
# ADR: docs/adr/0002-ADR-workstation-patching-update-only.md
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${CONFIG_PATH:-$ROOT/update-config.json}"
DRY_RUN=0
AUDIT=0
FAST=0
ONLY=""
SKIP=""
LOG_DIR="${LOG_DIRECTORY:-}"

usage() {
	cat <<'EOF'
Usage: update-devtools.sh [--dry-run] [--audit] [--fast] [--only LIST] [--skip LIST]

Update already-installed tools via Homebrew and/or apt|dnf|pacman inventory.
Native self-updaters (uv, bun, mise) run only when ownership is unambiguous.
EOF
}

tolower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

while [ $# -gt 0 ]; do
	case "$1" in
	--dry-run) DRY_RUN=1 ;;
	--audit) AUDIT=1 ;;
	--fast) FAST=1 ;;
	--only)
		ONLY="${2:-}"
		shift
		;;
	--skip)
		SKIP="${2:-}"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		usage >&2
		exit 1
		;;
	esac
	shift
done

have_cmd() { command -v "$1" >/dev/null 2>&1; }

csv_has() {
	# csv_has needle csv
	needle="$(tolower "$1")"
	old_ifs=$IFS
	IFS=','
	# shellcheck disable=SC2086
	set -- $2
	IFS=$old_ifs
	for x in "$@"; do
		[ "$(tolower "$x")" = "$needle" ] && return 0
	done
	return 1
}

manager_wanted() {
	name="$(tolower "$1")"
	if [ -n "$ONLY" ]; then
		csv_has "$name" "$ONLY" || return 1
	fi
	if [ -n "$SKIP" ]; then
		csv_has "$name" "$SKIP" && return 1
	fi
	if [ "$FAST" -eq 1 ] && [ "$name" = "apt" ]; then
		return 1
	fi
	return 0
}

STAMP="$(date -u +%Y%m%d-%H%M%S 2>/dev/null || date +%Y%m%d-%H%M%S)"
if [ -z "$LOG_DIR" ]; then
	LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mycmd/patching/logs"
fi
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/update-devtools-$STAMP.log"
JSON_FILE="$LOG_DIR/update-devtools-$STAMP.json"
: >"$LOG_DIR/results-$STAMP.txt"

log() {
	level="${2:-INFO}"
	line="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date) [$level] $1"
	echo "$line" | tee -a "$LOG_FILE"
}

record() {
	manager="$1"
	op="$2"
	status="$3"
	detail="${4:-}"
	# TSV side-car for summary (avoid fragile inline JSON escaping)
	printf '%s\t%s\t%s\t%s\n' "$manager" "$op" "$status" "$detail" >>"$LOG_DIR/results-$STAMP.txt"
	log "$manager/$op -> $status $detail"
}

path_hints() {
	p="$1"
	hints=""
	case "$p" in
	*/Cellar/* | */homebrew/* | */linuxbrew/* | */Homebrew/*) hints="$hints brew" ;;
	*/mise/* | */.local/share/mise/*) hints="$hints mise" ;;
	esac
	printf '%s' "$hints"
}

resolve_native() {
	cmd="$1"
	path="$(command -v "$cmd" 2>/dev/null || true)"
	if [ -z "$path" ]; then
		echo "SKIPPED_NOT_INSTALLED|$cmd not on PATH"
		return
	fi
	hints="$(path_hints "$path")"
	case " $hints " in
	*' brew '*)
		echo "SKIPPED_OWNERSHIP_AMBIGUOUS|under Homebrew ($path); let brew upgrade"
		return
		;;
	esac
	echo "OK|$path"
}

# --- Homebrew ---
if have_cmd brew && manager_wanted brew; then
	if [ "$DRY_RUN" -eq 1 ] || [ "$AUDIT" -eq 1 ]; then
		record brew audit ALREADY_CURRENT "Would run: brew update && brew upgrade"
	else
		if brew update && brew upgrade; then
			record brew upgrade UPDATED ""
		else
			record brew upgrade FAILED_PACKAGE_OPERATION "brew update/upgrade failed"
		fi
	fi
else
	record brew discover SKIPPED_NOT_INSTALLED "brew missing or filtered"
fi

# --- Linux system package manager (one) ---
UNAME="$(uname -s 2>/dev/null || echo unknown)"
if [ "$UNAME" = Linux ]; then
	if have_cmd apt-get && manager_wanted apt; then
		if [ "$DRY_RUN" -eq 1 ] || [ "$AUDIT" -eq 1 ]; then
			record apt audit ALREADY_CURRENT "Would run: apt-get update && apt-get upgrade"
		else
			if sudo -n true 2>/dev/null; then
				if sudo apt-get update && sudo apt-get upgrade -y; then
					record apt upgrade UPDATED ""
				else
					record apt upgrade FAILED_PACKAGE_OPERATION ""
				fi
			else
				record apt upgrade SKIPPED_PERMISSION "passwordless sudo unavailable"
			fi
		fi
	elif have_cmd dnf && manager_wanted dnf; then
		if [ "$DRY_RUN" -eq 1 ] || [ "$AUDIT" -eq 1 ]; then
			record dnf audit ALREADY_CURRENT "Would run: dnf upgrade"
		else
			if sudo -n true 2>/dev/null; then
				if sudo dnf upgrade -y; then
					record dnf upgrade UPDATED ""
				else
					record dnf upgrade FAILED_PACKAGE_OPERATION ""
				fi
			else
				record dnf upgrade SKIPPED_PERMISSION "passwordless sudo unavailable"
			fi
		fi
	elif have_cmd pacman && manager_wanted pacman; then
		if [ "$DRY_RUN" -eq 1 ] || [ "$AUDIT" -eq 1 ]; then
			record pacman audit ALREADY_CURRENT "Would run: pacman -Syu"
		else
			if sudo -n true 2>/dev/null; then
				if sudo pacman -Syu --noconfirm; then
					record pacman upgrade UPDATED ""
				else
					record pacman upgrade FAILED_PACKAGE_OPERATION ""
				fi
			else
				record pacman upgrade SKIPPED_PERMISSION "passwordless sudo unavailable"
			fi
		fi
	else
		record linux-pkg discover SKIPPED_NOT_INSTALLED "no apt/dnf/pacman or filtered"
	fi
fi

# --- Native self-updaters ---
for cmd in uv bun mise; do
	manager_wanted "$cmd" || continue
	res="$(resolve_native "$cmd")"
	status="${res%%|*}"
	detail="${res#*|}"
	if [ "$status" != OK ]; then
		record "$cmd" self-update "$status" "$detail"
		continue
	fi
	if [ "$DRY_RUN" -eq 1 ] || [ "$AUDIT" -eq 1 ]; then
		record "$cmd" self-update ALREADY_CURRENT "Would native self-update ($detail)"
		continue
	fi
	ok=0
	case "$cmd" in
	uv) uv self update && ok=1 ;;
	bun) bun upgrade && ok=1 ;;
	mise) mise self-update --yes && ok=1 ;;
	esac
	if [ "$ok" -eq 1 ]; then
		record "$cmd" self-update UPDATED "$detail"
	else
		record "$cmd" self-update FAILED_PACKAGE_OPERATION "$detail"
	fi
done

# JSON report (line-oriented; no secrets)
{
	echo "{"
	echo "  \"finishedUtc\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)\","
	echo "  \"dryRun\": $DRY_RUN,"
	echo "  \"audit\": $AUDIT,"
	echo "  \"logFile\": \"$LOG_FILE\","
	echo "  \"results\": ["
	first=1
	while IFS="$(printf '\t')" read -r manager op status detail; do
		[ -n "$manager" ] || continue
		if [ "$first" -eq 1 ]; then first=0; else echo ","; fi
		detail_esc=$(printf '%s' "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g')
		printf '    {"manager":"%s","operation":"%s","status":"%s","detail":"%s"}' \
			"$manager" "$op" "$status" "$detail_esc"
	done <"$LOG_DIR/results-$STAMP.txt"
	echo ""
	echo "  ]"
	echo "}"
} >"$JSON_FILE"

log "JSON report: $JSON_FILE"
echo "=== Summary written to $JSON_FILE ==="

fail=0
while IFS="$(printf '\t')" read -r _manager _op status _detail; do
	case "$status" in
	FAILED_*) fail=1 ;;
	esac
done <"$LOG_DIR/results-$STAMP.txt"

exit "$fail"
