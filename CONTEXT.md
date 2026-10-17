---
title: how-to-selfhost
description: Domain glossary and mycmd distribution architecture for this monorepo.
type: glossary
okf_version: "0.2"
tags: [selfhost, mycmd, recipes, glossary]
---

# how-to-selfhost

Repo-wide domain glossary and **mycmd distribution architecture**. Agents: read this before packaging, bootstrap, catalog, or release work.

Do **not** duplicate subtree runbooks or ops commands here — those live in [`AGENTS.md`](AGENTS.md) and nested READMEs. Progressive disclosure: [`knowledge/index.md`](knowledge/index.md).

---

## Where to read next

| Concern | Canonical doc |
|---------|----------------|
| Repo operating manual (map, validation, Git, boundaries) | [`AGENTS.md`](AGENTS.md) |
| Local AI / Qwen Spark recipe ops | [`scripts/local-ai/AGENTS.md`](scripts/local-ai/AGENTS.md) |
| Local AI human quickstart | [`scripts/local-ai/README.md`](scripts/local-ai/README.md) |
| Security VPS baseline quickstart | [`scripts/security/README.md`](scripts/security/README.md) |
| Scripts index | [`scripts/README.md`](scripts/README.md) |
| Issue tracker / triage / domain-doc rules | [`docs/agents/`](docs/agents/) |
| ADRs | [`docs/adr/`](docs/adr/index.md) via `/to-adr` |
| OKF concepts | [`knowledge/index.md`](knowledge/index.md) |
| Code graph (Graft) | `graft/` (gitignored). Rebuild: `graft build` |
| Local design notes (gitignored) | `pm/qwen-self-host/`, `docs/prd/` |

Other `scripts/*/README.md` files are the human SoT for that subtree.

---

## Glossary

| Term | Meaning | Avoid |
|------|---------|--------|
| **Recipe family** | Model/workload identity, e.g. `qwen3-8-flash-next` | Calling this a “package name” alone |
| **Target** | Hardware slug, e.g. `spark`, `rtx-6000-pro` (1–8 GPUs, one node; bare-metal or in-container via coarse `EXEC_MODE`). Future: `…-multi-node` for true multi-host — **out of scope**. | Equating target with recipe family; third URL path segment; per-provider target forks |
| **Recipe ID** | `<family>/<target>`, e.g. `qwen3-8-flash-next/spark` | Embedding version in the ID |
| **Release version** | Semver / prerelease for one recipe artifact, e.g. `0.0.1-rc1` | Repo-wide “latest” as the long-term resolver |
| **Channel** | `stable` \| `beta` \| `rc` \| `nightly` (mutable → immutable version). `beta` ↔ `rc` aliases in the Worker | Treating newest GitHub release as always stable |
| **Artifact** | Deterministic tarball + checksum, e.g. `qwen3-8-flash-next-spark-0.0.1-rc1.tar.gz` (≤2 GiB on GitHub Releases; larger → R2) | Hand-zipped dirs; weights/secrets inside |
| **Catalog** | Git-controlled manifest: recipe → channel → version → artifact URL/sha256 | Hardcoding GitHub URLs in the Worker |
| **Bootstrap** | Installer behind `get.mycmd.site/<project>/<recipe>[@channel\|version]`: resolve → download → verify → extract → mise → hand off to recipe | Embedding vLLM/GPU/PLE logic |
| **Recipe** | Independently packageable tree: `mise.toml`, `Justfile`, scripts, config, compose | Depending on unvendored `../../../shared.sh` |
| **Mise** | Pinned CLI tools (`python`, `uv`, `just`, …) via `mise install` | Machine provisioning / Docker / NVIDIA |
| **Just** | Human lifecycle commands | Fat logic in the Justfile (keep thin; scripts own logic) |
| **Maintainer wizard** | Interactive setup for Cloudflare/GitHub/secrets/CI | Bundling into public curl\|sh bootstrap |

---

## Current milestone

**Channel `rc` / public `@beta`:** `0.0.1-rc2` for Qwen local-ai targets (immutable GitHub Release tag `v0.0.1-rc2`). Prior spark `0.0.1-rc1` remains available by pin.

| Recipe ID | Artifact (rc2) |
|-----------|----------------|
| `qwen3-8-flash-next/spark` | `qwen3-8-flash-next-spark-0.0.1-rc2.tar.gz` |
| `qwen3-8-flash-next/rtx-6000-pro` | `qwen3-8-flash-next-rtx-6000-pro-0.0.1-rc2.tar.gz` |

Public URLs: `https://get.mycmd.site/<recipe-id>@beta` → catalog `rc` → above versions. Source trees under [`scripts/local-ai/recipes/qwen3-8-flash-next/`](scripts/local-ai/recipes/qwen3-8-flash-next/). Ops: [`scripts/local-ai/README.md`](scripts/local-ai/README.md).

**Topology note:** `rtx-6000-pro` covers **single-node** 1–8 GPUs with coarse `docker` vs `native` execution (upstream `vllm/vllm-openai:qwen38-flash-next` — no project Docker Hub image). A future **`multi-node`** target is reserved; not shipped.

**Also packaged (separate):** `security/vps-baseline` → `security-vps-baseline-0.0.1-rc1.tar.gz` (sha256 in catalog; release tag `security-vps-baseline-v0.0.1-rc1`). Source: [`scripts/security/`](scripts/security/).

Keep **recipe ID**, **release version**, and **storage location** separate so the public URL survives a later move off GitHub Releases.

---

## Recipe lifecycle contract

```text
mise install
just config | doctor | setup | deploy | probe | status | logs | benchmark | stop | token
# triage: just benchmark-load | gpu | snapshot | config --show
```
- **Mise:** tool versions. **Recipe:** host/GPU/Docker/model/compose/deploy/health/bench.
- Archive self-contained except weights + system packages.
- **Exclude:** weights, `.env`, credentials, logs, bench results, cache, temp, machine-local config.

---

## Distribution architecture

DNS configured **once**. Paths/versions are app concerns.

```text
get.mycmd.site  →  mycmd-bootstrap Worker  →  catalog (git)  →  GitHub Releases
```

### Public API

```text
/<project>/<recipe>
/<project>/<recipe>@stable
/<project>/<recipe>@beta
/<project>/<recipe>@nightly
/<project>/<recipe>@<immutable-version>
```

- Prefer path `@channel` / `@version`. Today: `@beta` (aliases catalog `rc` → current rc version per recipe); no `stable` yet.
- Legacy query still works: `?channel=rc|beta|stable`, `?version=<semver>`.
- Unqualified path defaults to channel `rc` (same alias set as `beta`).

Resolver: **git-controlled catalog** (not long-term `releases/latest` — monorepo has independently versioned recipes). Generic playbook: [`guides/how-to_distro_cloudflare_github.md`](guides/how-to_distro_cloudflare_github.md).

### Two pipelines

| Pipeline | Triggers | Does |
|----------|----------|------|
| Infrastructure | `bootstrap/**`, Wrangler | Deploy Worker (secrets in Actions) |
| Recipe release | recipe / release request | validate → package → checksum → test → immutable release → **update catalog** |

Package releases must **not** mutate Cloudflare/DNS. Published version = immutable (bad `0.0.1` → ship next version).

### What changes per event

| Event | DNS | Worker | Catalog | Release |
|-------|-----|--------|---------|---------|
| Initial `get.mycmd.site` | once | once | seed | — |
| New version / recipe | — | — / usually — | ✓ | ✓ |
| Resolver change / backend migrate | — | maybe | ✓ | — |

---

## Bootstrap protocol

Resolve recipe → version/channel → catalog → download + verify → extract → Mise → `just check`.  
No Qwen/vLLM/PLE logic in bootstrap.

---

## Implementation order (summary)

Freeze contract → build recipe locally → prove from git clone → deterministic archive (`scripts/packaging/package-recipe.sh`) → **manual** `0.0.1-rc1` release → catalog sha256 → Cloudflare Worker + `get.mycmd.site` (Actions + **HUMAN** secrets) → clean-machine curl E2E → automate recipe-release Actions → later targets / `uvx` bench / other backends.

**Key milestone:** clean host `curl -fsSL https://get.mycmd.site/qwen3-8-flash-next/<spark|rtx-6000-pro>@beta | sh` → `just doctor` → (on GPU host) `just setup` / `deploy` / `probe`. Prove recipe deploy (A) before distribution (B).

**Scaffold paths:** `bootstrap/` (Worker), `catalog/recipes.json`, `.github/workflows/deploy-bootstrap.yml`. Maintainer CF wizard (local): `pm/qwen-self-host/distro/`. ADR: [`docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md`](docs/adr/how-to-selfhost-0001-ADR-mycmd-site-distro.md).

---

## Graft

- CLI: `@nanonets/graft` (`graft init`, `graft build`, `graft ask`, …)
- Graph cache: `graft/` (gitignored; teammates run `graft build`)
- This repo is mostly shell — Graft’s parsers cover JS/TS/Python/Go/Rust/etc., **not** `.sh`. Expect a sparse graph until more typed source lands (e.g. bootstrap Worker, `uvx` bench).
- Cursor wiring is local under `.cursor/` (also gitignored here).

---

## Hard rules

1. **No glossary/ops duplication** — definitions here; commands and boundaries in `AGENTS.md`.
2. **`docs/prd/` ignored** (setup **A**); **ADRs tracked** under `docs/adr/`. Cite setup/ADR 0013 in the skills library; do not restate AGENTS bullets here.
3. **`pm/` stays local** — never stage; complementary scratch for design notes alongside ignored PRDs.

---

## See also

- [`knowledge/index.md`](knowledge/index.md)
- [`docs/adr/index.md`](docs/adr/index.md)
- [`AGENTS.md`](AGENTS.md)
