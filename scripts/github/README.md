# GitHub / Git auth scripts

Scripts for Git and GitHub authentication, especially in WSL2.

## Why use this

- **WSL2 + `gh`**: OAuth in WSL often fails to open a browser. This script configures `wslview` (Windows default browser) so `gh auth login` works and credentials persist.
- **One-time setup**: Install wslu if needed, set `gh` browser and `BROWSER` env, run `gh auth login`, then `gh auth setup-git`.

## High-level overview (what the script does)

| Script | Main actions |
|--------|--------------|
| **gh-wsl2-auth-setup.sh** | Detects WSL2; checks/installs wslu (wslview) and gh; sets `gh config set browser wslview` and `export BROWSER=wslview` in shell config; optionally runs `gh auth login`; runs `gh auth setup-git`; runs a quick auth test. No secrets written to disk. |

## gh-wsl2-auth-setup.sh

Configures **WSL2** so that GitHub CLI (`gh`) uses the **Windows default browser** for OAuth (via `wslview` from the `wslu` package). Ensures you don’t get stuck with “cannot open browser” errors when running `gh auth login` inside WSL.

- Checks for WSL2, `wslview`, and `gh`.
- Installs `wslu` (for `wslview`) if missing.
- Sets `gh config set browser wslview` and `export BROWSER=wslview` in your shell config.
- Runs `gh auth login` if not already authenticated, then `gh auth setup-git`.

**Run inside WSL2** (no sudo required for most steps; sudo only for apt install):

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/github/gh-wsl2-auth-setup.sh -O gh-wsl2-auth-setup.sh
chmod +x gh-wsl2-auth-setup.sh
./gh-wsl2-auth-setup.sh
```

After running, `source ~/.bashrc` (or your shell config) and test with `git push origin main`.
