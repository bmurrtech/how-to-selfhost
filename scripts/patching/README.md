# Workstation patching

Update **already installed** developer tools through the package manager that owns them. Do not use this to install a new stack.

Safety rules (see [ADR 0002](../../docs/adr/0002-ADR-workstation-patching-update-only.md)):

- Inventory first. Never install missing apps. Never bootstrap missing package managers.
- Never recover a failed update by installing via another manager.
- Ambiguous ownership → skip.
- No secrets in the Justfile.
- No mise required (extract-only bootstrap).

## Install on a host

```bash
# Windows (Git Bash) / macOS / Linux — pick the target that matches the OS
curl -fsSL "https://get.mycmd.site/patching/windows@beta" | bash
curl -fsSL "https://get.mycmd.site/patching/macos@beta" | bash
curl -fsSL "https://get.mycmd.site/patching/linux@beta" | bash
```

`@beta` → catalog `rc` → **`0.1.0-rc1`** (shared artifact `patching-devtools-0.1.0-rc1.tar.gz`; release tag `patching-devtools-v0.1.0-rc1`). Architecture: [`CONTEXT.md`](../../CONTEXT.md). Packaging: [`scripts/packaging/README.md`](../packaging/README.md).

After install (default root `$HOME/mycmd/patching/<target>`):

```bash
cd ~/mycmd/patching/windows   # or macos / linux
# Windows:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./Update-DevTools.ps1 -DryRun -NoElevate
# macOS / Linux:
./update-devtools.sh --dry-run
```

Optional: install [just](https://github.com/casey/just) yourself if you want `just dry-run` / `just update`. Mise is not used here.

## Prerequisites

| OS | Entrypoint | Managers (if present) |
|----|------------|------------------------|
| Windows 10/11 | `Update-DevTools.ps1` | WinGet, Chocolatey, Scoop; owned `uv` / `bun` / `mise` self-update |
| macOS / Linux | `update-devtools.sh` | Homebrew; apt **or** dnf **or** pacman; owned self-updaters |

## Quick start (from this repo)

```powershell
cd scripts\patching
.\Update-DevTools.ps1 -DryRun -NoElevate
.\Update-DevTools.ps1 -Audit -NoElevate
.\Update-DevTools.ps1
```

With just (optional):

```text
just dry-run
just audit
just update
just update-elevated
just schedule
just test
```

macOS / Linux:

```bash
cd scripts/patching
chmod +x update-devtools.sh
./update-devtools.sh --dry-run
./update-devtools.sh
# or: just dry-run-unix / just update-unix
```

## Elevation and scheduler (Windows)

Machine-scope managers (often Chocolatey) need an admin principal.

1. **Same user + UAC:** run `Update-DevTools.ps1` (AutoElevate). Cancel UAC → script continues; admin-only steps skip with `SKIPPED_PERMISSION`.
2. **Different admin user:** Shift+right-click PowerShell → Run as different user → sign in → `.\Update-DevTools.ps1 -NoElevate`. See `just update-elevated`.
3. **Unattended:** register a scheduled task that runs as that admin. Windows will prompt for the account password in the GUI/`schtasks` flow — never store it in the Justfile. See `just schedule`.

## Flags

| Flag | Effect |
|------|--------|
| `-DryRun` / `--dry-run` | Show intent; no upgrades |
| `-Audit` / `--audit` | Inventory-oriented report; no upgrades |
| `-Fast` / `--fast` | Skip slow managers listed in config `FastSkipManagers` |
| `-Only` / `--only` | Comma list of managers to run |
| `-Skip` / `--skip` | Comma list to exclude |
| `-NoElevate` | Do not request UAC (Windows) |

Config: `update-config.json` next to the scripts (retries, timeouts, skips, `WingetIncludeUnknown` default `false`).

## Logs

| OS | Default log directory |
|----|------------------------|
| Windows | `%LOCALAPPDATA%\mycmd\patching\logs` |
| macOS / Linux | `$XDG_STATE_HOME/mycmd/patching/logs` or `~/.local/state/mycmd/patching/logs` |

Each run writes a timestamped `.log` and `.json` summary. Exit `0` = no `FAILED_*`; `2` (Windows) / `1` (Unix) = partial failure.

## What this does not do

- Windows Update, Store, WSL, Defender, disk cleanup
- `npm` / `pnpm` / `yarn` global package updates
- `mise upgrade` (tool versions) — only `mise self-update` when ownership is clear
- Project dependency updates
- Deleting Chocolatey locks or changing ACLs after a failure

## Verify

```powershell
just test
# or:
Import-Module Pester -MinimumVersion 5.0
Invoke-Pester -Path .\Update-DevTools.Tests.ps1 -Output Detailed
```

Bootstrap preflight: `bash scripts/check.sh`. Local e2e helpers (not CI): `.scratch/patching/`.

## Release prep (maintainers)

```bash
bash scripts/packaging/package-recipe.sh patching/windows 0.1.0-rc1
# same artifact for macos/linux IDs
```

Then create GitHub Release `patching-devtools-v0.1.0-rc1`, paste sha256 into `catalog/recipes.json`, deploy bootstrap Worker if extract-only path is not yet live. Do not replace release assets — bump rc instead.

## Known limitations

- Split entrypoints can drift — keep statuses aligned when changing behavior.
- Live package-manager e2e is not shipped; use `.scratch/patching` on a disposable host.
- Public one-liner needs published Release + catalog sha256 + Worker with extract-only support.
