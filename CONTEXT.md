# CONTEXT.md

Repo-wide domain glossary and **mycmd distribution architecture**. Agents: read this before packaging, bootstrap, catalog, or release work.

Do **not** duplicate subtree runbooks here — follow the pointers below.

---

## Where to read next

| Concern | Canonical doc |
|---------|----------------|
| Repo operating manual (map, validation, Git, boundaries) | [`AGENTS.md`](AGENTS.md) |
| Local AI / Qwen Spark recipe ops | [`scripts/local-ai/AGENTS.md`](scripts/local-ai/AGENTS.md) |
| Local AI human quickstart | [`scripts/local-ai/README.md`](scripts/local-ai/README.md) |
| Scripts index | [`scripts/README.md`](scripts/README.md) |
| Issue tracker / triage / domain-doc rules | [`docs/agents/`](docs/agents/) |
| ADRs | `docs/ADRs/` via `/to-adr` — **not** Matt’s `docs/adr/` |
| Code graph (Graft) | `graft/` (gitignored). Rebuild: `graft build` |
| Local design notes (gitignored) | `pm/qwen-self-host/` |

Other `scripts/*/README.md` files are the human SoT for that subtree.

---

## Glossary

| Term | Meaning | Avoid |
|------|---------|--------|
| **Recipe family** | Model/workload identity, e.g. `qwen3-8-flash-next` | Calling this a “package name” alone |
| **Target** | Hardware/topology, e.g. `spark`, `spark-dual`, `rtx-6000-pro` | Equating target with recipe family |
| **Recipe ID** | `<family>/<target>`, e.g. `qwen3-8-flash-next/spark` | Embedding version in the ID |
| **Release version** | Semver / prerelease for one recipe artifact, e.g. `0.0.1-rc1` | Repo-wide “latest” as the long-term resolver |
| **Channel** | `stable` \| `rc` \| explicit `version=` | Treating newest GitHub release as always stable |
| **Artifact** | Deterministic tarball + checksum, e.g. `qwen3-8-flash-next-spark-0.0.1-rc1.tar.gz` | Hand-zipped dirs; weights/secrets inside |
| **Catalog** | Git-controlled manifest: recipe → channel → version → artifact URL/sha256 | Hardcoding GitHub URLs in the Worker |
| **Bootstrap** | Installer behind `get.mycmd.site/<family>/<target>`: resolve → download → verify → extract → mise → hand off to recipe | Embedding vLLM/GPU/PLE logic |
| **Recipe** | Independently packageable tree: `mise.toml`, `Justfile`, scripts, config, compose | Depending on unvendored `../../../shared.sh` |
| **Mise** | Pinned CLI tools (`python`, `uv`, `just`, …) via `mise install` | Machine provisioning / Docker / NVIDIA |
| **Just** | Human lifecycle commands | Fat logic in the Justfile (keep thin; scripts own logic) |
| **Maintainer wizard** | Interactive setup for Cloudflare/GitHub/secrets/CI | Bundling into public curl\|sh bootstrap |

---

## Current milestone

**First E2E proof:** `qwen3-8-flash-next/spark` → GitHub Release **`0.0.1-rc1`** → `get.mycmd.site` → clean Spark install.

| Contract | Value |
|----------|--------|
| Recipe ID | `qwen3-8-flash-next/spark` |
| Public URL | `https://get.mycmd.site/qwen3-8-flash-next/spark` |
| First artifact | `qwen3-8-flash-next-spark-0.0.1-rc1.tar.gz` (+ `.sha256`) |
| Source today | `scripts/local-ai/recipes/qwen3-8-flash-next/spark/` — details in [`scripts/local-ai/AGENTS.md`](scripts/local-ai/AGENTS.md) |

Keep **recipe ID**, **release version**, and **storage location** separate so the public URL survives a later move off GitHub Releases.

---

## Recipe lifecycle contract

```text
mise install
just check | setup | deploy | status | logs | benchmark | stop
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

- Stable: `https://get.mycmd.site/<family>/<target>`
- RC: `...?channel=rc` (or installer args)
- Pin: `...?version=0.0.1-rc1`

Resolver: **git-controlled catalog** (not long-term `releases/latest` — monorepo has independently versioned recipes).

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

**Key milestone:** clean Spark `curl -fsSL https://get.mycmd.site/qwen3-8-flash-next/spark?channel=rc | sh` → verified recipe + `just check`. Prove recipe deploy (A) before distribution (B).

**Scaffold paths:** `bootstrap/` (Worker), `catalog/recipes.json`, `.github/workflows/deploy-bootstrap.yml`. Maintainer CF wizard (local): `pm/qwen-self-host/distro/`. ADR: `docs/ADRs/how-to-selfhost-0001-ADR-mycmd-site-distro.md`.

---

## Graft

- CLI: `@nanonets/graft` (`graft init`, `graft build`, `graft ask`, …)
- Graph cache: `graft/` (gitignored; teammates run `graft build`)
- This repo is mostly shell — Graft’s parsers cover JS/TS/Python/Go/Rust/etc., **not** `.sh`. Expect a sparse graph until more typed source lands (e.g. bootstrap Worker, `uvx` bench).
- Cursor wiring is local under `.cursor/` (also gitignored here).
