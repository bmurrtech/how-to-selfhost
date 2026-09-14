#!/usr/bin/env bash
# Pac-Man-style ASCII progress for long-running deploy steps.
# Yellow C/c "eats" dots; shows percentage + label.
# shellcheck shell=bash

# Pac-Man yellow (xterm 226 ≈ classic arcade yellow)
PACMAN_YELLOW=$'\033[38;5;226m'
PACMAN_DIM=$'\033[2m'
PACMAN_RESET=$'\033[0m'

# pacman_progress <percent 0-100> <label>
# Renders a single updating line. Call with 100 then pacman_progress_done.
pacman_progress() {
	local pct="${1:-0}"
	local label="${2:-}"
	local width="${PACMAN_WIDTH:-28}"
	local filled empty i frame mouth bar

	if ! [[ "$pct" =~ ^[0-9]+$ ]]; then pct=0; fi
	if ((pct < 0)); then pct=0; fi
	if ((pct > 100)); then pct=100; fi

	filled=$(((pct * width) / 100))
	empty=$((width - filled))

	# Alternate mouth: C then c
	frame=$((${PACMAN_FRAME:-0} + 1))
	PACMAN_FRAME=$frame
	if ((frame % 2 == 0)); then mouth='C'; else mouth='c'; fi

	bar=""
	for ((i = 0; i < filled; i++)); do bar+=' '; done
	bar+="${PACMAN_YELLOW}${mouth}${PACMAN_RESET}"
	for ((i = 0; i < empty; i++)); do bar+="${PACMAN_DIM}.${PACMAN_RESET}"; done

	printf '\r[%s] %3d%% %s' "$bar" "$pct" "$label" >&2
}

pacman_progress_done() {
	local label="${1:-done}"
	pacman_progress 100 "$label"
	printf '\n' >&2
}

# pacman_spin_until <timeout_sec> <label> <command...>
# Polls command until exit 0; advances faux progress toward 95% while waiting.
pacman_spin_until() {
	local timeout="${1:?timeout}"
	local label="${2:?label}"
	shift 2
	local start now elapsed pct
	start=$(date +%s)

	while true; do
		if "$@"; then
			pacman_progress_done "$label"
			return 0
		fi
		now=$(date +%s)
		elapsed=$((now - start))
		if ((elapsed >= timeout)); then
			printf '\n' >&2
			echo "Timeout after ${timeout}s: $label" >&2
			return 1
		fi
		# Asymptotic approach to 95% while waiting
		pct=$(((elapsed * 95) / (elapsed + 30)))
		pacman_progress "$pct" "$label (${elapsed}s)"
		sleep 2
	done
}

# pacman_run_phases: call between known steps with explicit percents
# Usage: pacman_phase 10 "pulling image"
pacman_phase() {
	pacman_progress "${1:?pct}" "${2:-}"
}
