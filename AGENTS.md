# AGENTS.md

Operating manual for coding agents in **how-to-selfhost**. Prefer the smallest coherent change, verify it, then report what ran.

This file does not replace guides, READMEs, or source. Domain glossary + mycmd distribution architecture: [`CONTEXT.md`](CONTEXT.md). PRDs under gitignored `docs/prd/` (setup **A**).

---

## Project overview

Public self-hosting guides (`guides/`) plus executable scripts (`scripts/`) for security hardening, game servers, WireGuard, GitHub/WSL auth, and local LLM recipes. Near-term product work is packaging/distributing recipe tarballs (first: `scripts/local-ai` → via `get.mycmd.site`). Operators use **mise** + **just** for the recipe lifecycle.

---

## Project map

| Path | Role |
|------|------|
| `guides/` | Human how-to markdown |
| `scripts/` | Executable scripts + per-folder READMEs — index: [`scripts/README.md`](scripts/README.md) |
| `scripts/local-ai/` | First packageable recipe tree (mise + just) |
| `docs/agents/` | Skill config: issue tracker, triage labels, domain-doc rules |
| `docs/adr/` | ADRs via `/to-adr` — index: [`docs/adr/index.md`](docs/adr/index.md) |
| `docs/prd/` | PRDs (ignored) |
| `knowledge/` | OKF concepts — [`knowledge/index.md`](knowledge/index.md) |
| `CONTEXT.md` | Glossary + distribution / bootstrap / catalog architecture |
| `CHANGELOG.md` | Recipe-release notes (Keep a Changelog; Unreleased + per-recipe versions) |
| `bootstrap/` | Cloudflare Worker (`get.mycmd.site`) + Wrangler |
| `catalog/` | Git-controlled recipe → channel → version → artifact map |
| `graft/` | Local Graft graph cache (gitignored; sparse until typed source lands) |
| `pm/` | Local-only notes/PRDs (gitignored — never stage) |
| `.scratch/` | Local agent scratch (diagrams, adr-optics; gitignored) |
| `.github/workflows/` | Infra: deploy bootstrap Worker (Wrangler) |

---

## Development workflow

```text
orient (map + triggered nested AGENTS/README)
→ edit the narrowest subtree
→ targeted static check on changed files
→ required broader validation for that subtree
→ report paths changed + commands run (exit codes)
```

Do not invent a monorepo root build — there is no root `package.json`. Infra CI exists for the bootstrap Worker only (`.github/workflows/deploy-bootstrap.yml`).

---

## Setup & validation (repo-wide)

Most trees are shell. For any edited `*.sh`:

```bash
bash -n path/to/script.sh
shellcheck -x -e SC1091 path/to/script.sh
shfmt -d -i 0 path/to/script.sh   # when shfmt is available (e.g. via mise in local-ai)
```

**Before calling work complete on script changes:** every edited `.sh` passes `bash -n` + `shellcheck` (and `shfmt -d` when the tool is on PATH). Do not claim a check passed unless the command finished successfully.

Subtree-specific install/run loops live in nested docs (see **Further instructions**).

---

## Testing

| Seam | Command | Notes |
|------|---------|-------|
| _(none indexed yet)_ | | Add test-map rows in `knowledge/` as seams land |

---

## Code conventions

- Prefer idempotent scripts; document destructive steps in the folder README.
- Shell: `set -euo pipefail` unless an existing file intentionally differs.
- Format/lint shell with `shfmt` + `shellcheck` only — do not hand-reformat.
- Secrets and tokens only via env / `.env` (gitignored); never hardcode; never echo secrets or `--api-key` values into logs.
- Use glossary terms from [`CONTEXT.md`](CONTEXT.md) when naming recipes, targets, artifacts, channels, or catalogs.

---

## Git & PR workflow

- Default branch: `main`. Issues: GitHub (`gh`) — [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).
- Triage labels: [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).
- Commit style in this repo: short conventional prefixes (`feat:`, `fix:`, `docs:`, …).
- Commit / push / open a PR only when the user explicitly asks.
- Never commit secrets or ignored trees (`pm/`, `docs/prd/`, `.scratch/`, agent dirs, `.env`, `scripts/local-ai/.env`, `**/.runtime.env*`, `graft/`, `bootstrap/.dev.vars`, `dist/`).

Infra workflow: `.github/workflows/deploy-bootstrap.yml` (Wrangler). Recipe-release automation not required for first manual `0.0.1-rc1`.

---

## Boundaries

| Do | Don't | Why |
|----|-------|-----|
| Load secrets from `.env` / env | Commit `.env` or print secrets | Credential exposure |
| Keep `/pm/` and `docs/prd/` local | `git add pm/` or `docs/prd/` | Intentionally gitignored |
| Regenerate Graft with `graft build` | Commit `graft/` | Local cache; teammates rebuild |
| Record decisions with `/to-adr` → `docs/adr/` | Invent a second ADR home | bmurrtech standard path |
| Package releases update catalog only | Change DNS/Worker on every recipe version | Distribution contract in `CONTEXT.md` |

---

## Agent skills

- **Issue tracker:** GitHub Issues — [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)
- **Triage labels:** defaults — [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md)
- **Domain docs:** [`CONTEXT.md`](CONTEXT.md) + [`docs/adr/`](docs/adr/) + [`knowledge/`](knowledge/index.md) — [`docs/agents/domain.md`](docs/agents/domain.md)

---

## Further instructions

| When working on… | Read |
|------------------|------|
| **Local AI / Qwen Spark recipe** (serve, just recipes, PLE mmap, `.env`) | [`scripts/local-ai/AGENTS.md`](scripts/local-ai/AGENTS.md) then [`scripts/local-ai/README.md`](scripts/local-ai/README.md) |
| **Packaging, bootstrap, catalog, `get.mycmd.site`, release channels** | [`CONTEXT.md`](CONTEXT.md) first |
| **Any other `scripts/<area>/`** | That folder’s `README.md` (and nested READMEs) |
| **Orientation via code graph** (when typed source exists) | `graft ask "…"`, `graft map`; rule: `.cursor/rules/graft.mdc` |
| **Local design SoT (PRDs/status)** | `docs/prd/` or `pm/` (gitignored; do not commit) |
