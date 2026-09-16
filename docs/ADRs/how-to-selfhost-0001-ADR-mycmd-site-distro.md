# how-to-selfhost-0001-ADR-mycmd-site-distro

<!-- File: docs/ADRs/how-to-selfhost-0001-ADR-mycmd-site-distro.md -->

## Status
Accepted
- **Date:** 2026-09-14
- **Related PRDs:**
  - [`pm/qwen-self-host/PRDs/003-PRD-mycmd-site-distro.md`](../../pm/qwen-self-host/PRDs/003-PRD-mycmd-site-distro.md)

---

## Context
We need a public one-liner installer (`get.mycmd.site/<family>/<target>`) for independently versioned recipe artifacts in a monorepo. Recipe releases must not require DNS or Worker redeploys. Operators must verify downloads. Maintainers need Cloudflare + GitHub Actions without baking secrets into git.

### Drivers / Forces
- Stable public URL that survives storage backend moves
- Independent recipe versioning (not repo-wide `latest`)
- Low ops cost (Cloudflare Workers + GitHub Releases)
- Secrets never in source; humans own API token creation

### Assumptions
- `mycmd.site` (or zone hosting `get.mycmd.site`) is manageable in Cloudflare
- First recipe artifact is published as a GitHub Release asset
- Catalog JSON in git is the authoritative resolver input

### Constraints
- Package/release pipelines must not mutate DNS or Worker config
- Published release versions are immutable (bad ship → next semver)
- Artifacts never contain weights, `.env`, or credentials
- Bootstrap contains no model/GPU/PLE logic

---

## Decision
**We will:** resolve installs via a Cloudflare Worker at `get.mycmd.site` that reads a **git-controlled catalog**, returns a shell installer which downloads + checksum-verifies a GitHub Release artifact, then hands off to Mise/`just`. Deploy the Worker with Wrangler from GitHub Actions using repo secrets. Humans create Cloudflare resources and paste API credentials into GitHub Secrets (and local gitignored `.env` for optional `wrangler` dry-runs).

### Rationale (Why this decision)
- Separates **recipe ID**, **release version**, and **storage URL** so the public path stays stable
- Catalog-in-git updates on every recipe release without touching Cloudflare
- Workers + Actions match the repo’s shell-first, low-infra posture
- Human-owned secrets keep tokens out of agent/CI logs and git history

### Alternatives considered
#### Option A: Point DNS straight at GitHub Releases / `releases/latest`
- **Pros:** No Worker
- **Cons:** Couples public URL to GitHub; `latest` breaks multi-recipe versioning; hard to pin channels
- **Why not chosen:** CONTEXT requires channel/version resolution independent of storage

#### Option B: Host catalog only on R2 / KV without git
- **Pros:** Fast reads
- **Cons:** Second source of truth; release PRs wouldn’t show resolver diffs
- **Why not chosen:** Git catalog is the reviewable SoT; Worker may cache later

#### Option C: Embed full catalog in the Worker at deploy time only
- **Pros:** Simple offline Worker
- **Cons:** Every catalog bump redeploys infrastructure pipeline
- **Why not chosen:** Violates “package releases update catalog only”

---

## Implementation Notes (Normative)

### Architecture / Boundaries
- **Public API:** `https://get.mycmd.site/<project>/<recipe>[@stable|beta|nightly|rc|<version>]`; legacy `?channel=` / `?version=` still accepted. `beta` ↔ `rc` channel aliases.
- **Bootstrap Worker** (`bootstrap/`): resolve → emit installer shell. No recipe runtime logic.
- **Catalog** (`catalog/recipes.json`): recipe ID → channels → version → artifact URL + sha256
- **Artifacts:** GitHub Release assets named `<family>-<target>-<version>.tar.gz` (+ `.sha256`)
- **Two pipelines:** (1) infra: deploy Worker on `bootstrap/**` changes; (2) recipe: package → release → update catalog (no Cloudflare mutate)

### Security & Data Handling (Baseline)
- **Secrets / vars:** `CLOUDFLARE_API_TOKEN` → GitHub Actions **secret**; `CLOUDFLARE_ACCOUNT_ID` → GitHub Actions **variable** (non-secret). Optional zone IDs stay in local gitignored `.env` — never committed
- **Storage:** no secrets inside tarballs or Worker source
- **Logging:** never log token values or `--api-key` material
- **AuthN/AuthZ:** public GET installer; write paths are GitHub + Cloudflare dashboards / Actions only
- **Supply chain:** pin Wrangler action versions; verify sha256 before extract

### Quality Gates (CI/CD)
- **Testing expectation:** Worker unit/smoke for path + channel resolution; `bash -n` on installer string where practical
- **Static checks:** typecheck Worker; shellcheck packaging scripts when present
- **Build / release rules:** infra workflow deploys Worker only; recipe workflow (later) must not call Wrangler

### Operational / DevOps Decisions
- **Deployment model:** Wrangler → Cloudflare Workers; custom domain `get.mycmd.site`
- **Environments:** production on `main`; `workflow_dispatch` for manual redeploy
- **Config management:** `wrangler.toml` + Actions secrets; local maintainer `.env` via wizard under `pm/qwen-self-host/distro/`
- **Observability:** Worker request logs in Cloudflare dashboard (MVP)
- **Scaling posture:** Worker default limits sufficient for installer traffic

### Versioning & Compatibility
- Catalog `schema` field; bump when resolver shape breaks
- Immutable release tags/assets; channels are pointers in catalog only

---

## Consequences
### Positive
- Stable curl URL; independent recipe versions; reviewable resolver diffs in git

### Negative / Trade-offs
- Requires Cloudflare account + human secret paste
- Catalog fetch depends on GitHub raw availability (mitigate with Worker cache later)

### Risks & Mitigations
- Wrong/missing sha256 → installer fails closed → require sha256 before marking channel live
- Secret leakage in logs → never echo tokens; prefer `gh secret set` / dashboard paste

### Follow-ups (Optional)
- Automate recipe-release Actions after first manual `0.0.1-rc1`
- Optional KV/R2 mirror of catalog for resilience

---

## References
- [`CONTEXT.md`](../../CONTEXT.md)
- [`pm/qwen-self-host/PRDs/003-PRD-mycmd-site-distro.md`](../../pm/qwen-self-host/PRDs/003-PRD-mycmd-site-distro.md)
- [`bootstrap/`](../../bootstrap/)
- [`catalog/recipes.json`](../../catalog/recipes.json)
