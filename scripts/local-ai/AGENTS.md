# Agent context: `scripts/local-ai`

Operating manual for agents changing or running code under `scripts/local-ai/`. Human quickstart: [`README.md`](README.md). Repo-wide rules: root [`AGENTS.md`](../../AGENTS.md). Packaging / `get.mycmd.site` / catalog vocabulary: root [`CONTEXT.md`](../../CONTEXT.md).

Local design SoT (gitignored): `pm/qwen-self-host/` (e.g. `PRDs/002-PRD-mise-just.md`).

---

## Project overview

Reproducible **Qwen3.8-Flash-Next-NVFP4** on **DGX Spark** and **RTX PRO 6000** (1–8 GPUs, single node; bare-metal Docker or native-in-vLLM). Operator UX is `just` via `mise`. Recipe IDs: `qwen3-8-flash-next/{spark,rtx-6000-pro}` (see `CONTEXT.md`).

---

## Project structure

- `recipes/qwen3-8-flash-next/spark/` — PLE mmap Compose path
- `recipes/qwen3-8-flash-next/rtx-6000-pro/` — unified RTX PRO 6000 (docker + native modes, profiles, RunPod guide in README)
- `scripts/lib/` — shared `load_env`, `config_env`, `weights`, `resolve_serve`, `rtx_serve`, `docker_nct`, `pacman_progress`, `recipe_common`
- Reserved skeleton dirs (`hosts/`, `topologies/`, `runtimes/`, `models/`, …) — unpopulated (`.gitkeep` only)
- `.env` / `.runtime.env` / `.run/` — gitignored local state

---

## Development workflow

```text
mise install → edit recipe/scripts → static checks on edited *.sh
→ just doctor → (on host) just setup / deploy / probe
→ optional just benchmark → report commands + outcomes
```

Prove recipe deploy on a clone **before** debugging distribution (`CONTEXT.md` Problem A vs B).

---

## Setup & build

```bash
cd scripts/local-ai
mise install
cp .env.example .env && chmod 600 .env   # set VLLM_API_KEY, HF_TOKEN
just setup                               # pinned image + weights; idempotent
```

Lifecycle: `just doctor | probe | benchmark | setup | deploy | status | logs | stop` (Justfile thin — logic in scripts). Troubleshoot: `benchmark-load`, `gpu`, `snapshot`.

---

## Testing & validation

**While iterating (required on every edited `*.sh`):**

```bash
bash -n path/to/file.sh
shellcheck -x -e SC1091 path/to/file.sh
shfmt -d -i 0 path/to/file.sh
```

**On Spark before completion of deploy-affecting changes:**

```bash
just doctor
just deploy    # run twice when claiming idempotency
just probe
just status
# optional: just benchmark
```

Do not claim an interrupted/timed-out on-host run passed. Do not weaken a check to make a change pass.

---

## Code conventions

- Format/lint with `shfmt` + `shellcheck` only.
- `set -euo pipefail`; knobs in `config/serve.env`, not scattered inline defaults.
- Justfile thin; implementation in `recipes/.../scripts/` and `scripts/lib/`.

---

## Boundaries

- Secrets only via `.env`; never echo `VLLM_API_KEY` / `HF_TOKEN` or logs bearing `--api-key`.
- Never commit `.env` / `.runtime.env`.
- 1× Spark SoT is **PLE mmap** — stock `vllm/vllm-openai:qwen38-flash-next` OOMs (~121 GiB); do not treat stock full-residency as the Spark path.
- This pass: do not reintroduce llmux as required path or an external bench-matrix harness unless the user asks.
- Stay inside `scripts/local-ai/` for implementation; report failed commands — do not guess results.
- Artifact packaging must not include weights, `.env`, credentials, logs, caches (see `CONTEXT.md`).

---

## Gotchas

- RTX RunPod: `rtx_prefer_volume_cache` defaults caches under writable `/workspace` (else `/runpod-volume`); explicit `HF_*` / `VLLM_CACHE_ROOT` win.
- Keep `prompt_tokens + max_tokens ≤ CTX` (default CTX 16384).
- Raise `SEQS` before concurrency sweeps or aggregate tok/s flatlines.
