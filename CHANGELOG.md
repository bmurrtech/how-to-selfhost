# Changelog

All notable **recipe release** changes for this repository. Versions below are **per-recipe** release versions (GitHub Release tags like `v0.0.1-rc2`), not a single monorepo semver for every path.

Format inspired by [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

### Changed

### Fixed

## [0.1.0-rc1] — 2026-10-28

### Added

- Recipe family `bottlecapai-thinkingcap-qwen3.8-27B-nvfp4/{spark,rtx-6000-pro}` — ThinkingCap NVFP4 dense serve (MTP=3, FP8 KV, gated HF); Spark e2e probe green.
- Recipe `orcarouter-qwen3.8-27B-uncensored-nvfp4/spark` — abliterated NVFP4 dense serve (research / authorized use).
- Recipe family `patching/{windows,macos,linux}` — update-only workstation maintenance (`scripts/patching/`); shared artifact `patching-devtools-0.1.0-rc1.tar.gz`; extract-only bootstrap (`.mycmd-extract-only`); ADR 0002.
- Bootstrap Worker: skip mise/`just` when recipe ships `.mycmd-extract-only`; download/verify before mise for all recipes.
- Packaging: `package-recipe.sh` supports bottlecap spark/rtx, orcarouter spark, and `patching/{windows,macos,linux}`.
- Local-ai: Kilo Code client notes in `scripts/local-ai/README.md` (openai-compatible map key = served model id).

### Changed

- Local-ai Just recipes: `ensure-mise` / `install-tools` → `mise` / `install`.
- Probe: ThinkingCap defaults to thinking-off (`PROBE_ENABLE_THINKING=0`) with reasoning fallback in `ops_probe.sh`.
- Agent scaffold: ADR home `docs/ADRs/` → `docs/adr/` (bmurrtech); OKF `knowledge/` stub; PRDs stay gitignored under `docs/prd/` (setup **A**); `.scratch/` + `CLAUDE.md` pointer.

### Notes

- Local-ai assets ship under GitHub Release tag **`v0.1.0-rc1`** (prerelease). Patching ships under **`patching-devtools-v0.1.0-rc1`** (separate tag; same catalog version).
- **Immutable:** once tags ship, never replace assets — bump rc instead.
- Gated weights / HF token required for ThinkingCap; not packaged in artifacts.

### Artifacts

| Recipe | Artifact | SHA-256 |
|--------|----------|---------|
| bottlecap spark | `bottlecapai-thinkingcap-qwen3.8-27B-nvfp4-spark-0.1.0-rc1.tar.gz` | `befe63a17e21103cdca84b47974a1efa13719c77894fe13d122637cd4d446c06` |
| bottlecap rtx | `bottlecapai-thinkingcap-qwen3.8-27B-nvfp4-rtx-6000-pro-0.1.0-rc1.tar.gz` | `ebeaf05bcddf54be48549712f0219e2f755e2f69749cf5c74b280bc98daa6ca5` |
| orcarouter spark | `orcarouter-qwen3.8-27B-uncensored-nvfp4-spark-0.1.0-rc1.tar.gz` | `8eda776d8698c63284d163057c9ed9cedc5c42b84fa8a37d4815d181db55ef4a` |
| patching (shared) | `patching-devtools-0.1.0-rc1.tar.gz` | `c22cf5224234cc117937518a49846e28201fc901315bb07b9ed8233614f31b29` |

Installer / URL contract: [`guides/how-to_distro_cloudflare_github.md`](guides/how-to_distro_cloudflare_github.md). Ops: [`scripts/local-ai/README.md`](scripts/local-ai/README.md), [`scripts/patching/README.md`](scripts/patching/README.md).

## [0.0.1-rc2] — 2026-09-15

### Added

- Recipe `qwen3-8-flash-next/rtx-6000-pro` — **one** artifact for bare-metal Docker **and** native-in-container (RunPod) via coarse `EXEC_MODE`; upstream `vllm/vllm-openai:qwen38-flash-next` only (no project Docker Hub image); GPU profiles 1–8; push-limit serve defaults (`auto` ctx, 8192 batched, 256 seqs, 0.95 util).
- RunPod ergonomics: prefer writable `/workspace` (else `/runpod-volume`) for `HF_CACHE` / `VLLM_CACHE_ROOT`; strong vs weak `VLLM_API_KEY` handling in `just config`.
- Troubleshooting surface (spark + rtx): `just doctor` (=`check`), `just config --show`, `just probe`, `just benchmark` / `benchmark-load` (wraps `vllm bench serve`), `just gpu`, filtered `just logs`, `just snapshot`.
- Shared `just config` / `just token`; interactive GPU/knob prompts on TTY.
- Root `CHANGELOG.md` and multi-target packaging in `scripts/packaging/package-recipe.sh`.
- Bootstrap path `@beta` / `@rc` / `@<version>` aliases; catalog channel `beta`↔`rc`.

### Changed

- Spark: `just config` bootstraps `.env` (generate/preserve API key); doctor disk FAIL under ~50 GiB free.
- Catalog `rc` for spark → `0.0.1-rc2`.
- Collapsed earlier metal/runpod split into unified `rtx-6000-pro`.

### Notes

- Security mise/just (`security/vps-baseline`) is a **separate** release tag (see below).
- Image digests in recipe.yaml remain `PENDING_RELEASE_PIN` until release-day pin.
- Experimental GPU profiles still require confirm / `PROFILE_CONFIRM=1`.
- **Immutable:** once `v0.0.1-rc2` ships on GitHub Releases, never replace assets — bump to rc3 instead.

### Artifacts

Built from packaging tree at commit of this changelog update (rebuilt 2026-09-15 after ops surface). `v0.0.1-rc2` **not yet published** at changelog write time — create the Release with these files:

| Recipe | Artifact | SHA-256 |
|--------|----------|---------|
| spark | `qwen3-8-flash-next-spark-0.0.1-rc2.tar.gz` | `c73bdd8a37a2b3e362afb5b49ed39c95700bb8573558120cc3cf34f844048eb4` |
| rtx-6000-pro | `qwen3-8-flash-next-rtx-6000-pro-0.0.1-rc2.tar.gz` | `de731d0b649feab5d5f471dd2eac3948a7fb8ab862532d3970a788836d14e74f` |

Installer / URL contract: [`guides/how-to_distro_cloudflare_github.md`](guides/how-to_distro_cloudflare_github.md). Ops: [`scripts/local-ai/README.md`](scripts/local-ai/README.md).

## [security/vps-baseline 0.0.1-rc1] — 2026-09-15

### Added

- Packageable `security/vps-baseline` (mise + just): `check` / `doctor` / `user` / `harden` / `f2b`; archive/ keeps wget-compatible copies.

### Artifacts

| Recipe | Artifact | SHA-256 |
|--------|----------|---------|
| security/vps-baseline | `security-vps-baseline-0.0.1-rc1.tar.gz` | `96b9b45a1b0033256214a5df1f85e8fd9131e38e43cb5559bbeab9a686b304f9` |

Release tag: `security-vps-baseline-v0.0.1-rc1` (separate from local-ai `v0.0.1-rc2`).

## [0.0.1-rc1] — 2026-09 (spark)

### Added

- First public recipe `qwen3-8-flash-next/spark` (PLE mmap on DGX Spark).
- Bootstrap Worker + catalog + packaging path for `get.mycmd.site`.

### Artifacts

| Recipe | Artifact | SHA-256 |
|--------|----------|---------|
| spark | `qwen3-8-flash-next-spark-0.0.1-rc1.tar.gz` | `7f0180b74186fdc2bb4d52463ed2f3d5ac29921aaf71652da45c4b54bb3b4e27` |

Source commit (historical release notes): `4c6ca2918c1775feda8a432b0247b6e66b025b2f`. Channel: `rc` (no stable). Immutable: do not replace these assets.
