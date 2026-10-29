# Workstation patching: update-only, split entrypoints

<!-- File: docs/adr/0002-ADR-workstation-patching-update-only.md -->

## Status
Accepted
- **Date:** 2026-10-28
- **Supersedes:** —
- **Superseded by:** —
- **Related ADRs:** [0001-ADR-mycmd-site-distro.md](0001-ADR-mycmd-site-distro.md)
- **Related PRDs:** [`.scratch/prd/0001-PRD-workstation-patching.md`](../../.scratch/prd/0001-PRD-workstation-patching.md) (local scratch; not tracked)

## Context and Problem Statement
How should this repo ship a cross-platform developer-workstation maintenance helper that refreshes already-installed tools without becoming an installer, without turning repository outages into cross-manager installs, and without requiring PowerShell 7 on every Unix host?

## Decision Drivers
* Never install software that is not already installed; never bootstrap missing package managers
* Survive shared Chocolatey/WinGet/source outages with bounded retries — no fallback install
* Work on typical Windows / macOS / Linux dev machines without adding a second runtime where avoidable
* Support Task Scheduler under an admin principal and interactive elevation without secrets in Justfiles
* Stay far simpler than updateEverything-scale flag and task surfaces

## Considered Options
* Single PowerShell 7 script everywhere (`pwsh` prerequisite on Mac/Linux)
* Split OS entrypoints (`.ps1` + `.sh`) with shared config and status vocabulary
* Wrap or fork updateEverything with most flags removed

## Decision Outcome
Chosen option: "Split OS entrypoints (`.ps1` + `.sh`) with shared config and status vocabulary", because it matches “any machine,” keeps package-manager calls idiomatic per OS, and still allows one recipe family (`patching/{windows,macos,linux}`) with extract-only bootstrap.

### Consequences
* Good, because Windows can stay close to WinGet/Chocolatey/Scoop semantics without forcing `pwsh` on Unix
* Good, because update-only + ownership-skip + no cross-manager fallback are enforceable as normative rules
* Bad, because two codepaths can drift — mitigated by shared statuses, shared config keys, and mocked tests on the contract
* Bad, because catalog/Worker must eventually serve OS-native one-liners (`irm|iex` vs `curl|bash`)

### Confirmation
Dry-run and audit never install; package-specific Chocolatey upgrades never run for non-inventory packages; a simulated HTTP 504 yields bounded retry then `FAILED_SOURCE_UNAVAILABLE` with no WinGet/Scoop fallback; Justfile contains no credentials.

## Pros and Cons of the Options

### Single PowerShell 7 script everywhere
* Good, because one implementation file
* Bad, because Mac/Linux often lack `pwsh`; adds a runtime prerequisite the recipe must not bootstrap
* Why not chosen: conflicts with “works on any dev machine” at higher weight than “one file”

### Split OS entrypoints (`.ps1` + `.sh`)
* Good, because native shells and schedulers; clear `get.mycmd.site` target split
* Bad, because duplicated orchestration discipline across two languages

### Wrap or fork updateEverything
* Good, because mature task runner patterns exist locally under `pm/repos/updateEverything`
* Bad, because large flag surface, system/cleanup tasks, and optional cross-manager fallback conflict with this safety bar
* Why not chosen: inspiration only; not a dependency

## Assumptions
- Operators who need machine-scope updates can register a scheduled task as an admin user or use OS “Run as different user”
- Mise/just are optional conveniences; direct script invoke remains supported
- Catalog packaging for `patching/*` follows ADR 0001 patterns in a later slice

## Constraints
- Never put secrets in the Justfile
- Never auto-install missing apps or package managers
- Never delete locks/caches/ACLs as automatic recovery
- Do not use WinGet `--include-unknown` unless config explicitly enables it
- Extract-only bootstrap (no mise install in the public installer for this recipe)

## Implementation Notes (Normative)
- Entrypoints: `scripts/patching/Update-DevTools.ps1`, `scripts/patching/update-devtools.sh`
- Shared sidecar: `scripts/patching/update-config.json` (conservative defaults)
- Status vocabulary includes at least: `UPDATED`, `ALREADY_CURRENT`, `SKIPPED_NOT_INSTALLED`, `SKIPPED_PINNED`, `SKIPPED_OWNERSHIP_AMBIGUOUS`, `SKIPPED_PERMISSION`, `FAILED_SOURCE_UNAVAILABLE`, `FAILED_PERMISSION`, `FAILED_PACKAGE_OPERATION`, `FAILED_UNKNOWN`
- Chocolatey: update from local inventory / `upgrade all` paths only after manager presence; never `choco upgrade <pkg>` for packages not shown installed
- Ownership ambiguous → skip; no dual-manager update in one run
- Transient source failures: bounded retries (default 3; ~15/30/60s + jitter); continue other managers
- Elevation: AutoElevate when same-user UAC can help; `-NoElevate` skips; scheduler docs assume admin task principal; `just update-elevated` must not embed passwords

## References
- [`CONTEXT.md`](../../CONTEXT.md) — Workstation patching glossary
- [`scripts/patching/`](../../scripts/patching/)
