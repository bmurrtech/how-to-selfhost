# Agent context: `scripts/local-ai`

Operating manual for agents changing or running code under `scripts/local-ai/`. Human quickstart: [`README.md`](README.md). Repo-wide rules: root [`AGENTS.md`](../../AGENTS.md). Packaging / `get.mycmd.site` / catalog vocabulary: root [`CONTEXT.md`](../../CONTEXT.md).

Local design SoT (gitignored): `pm/qwen-self-host/` (e.g. `PRDs/local-ai_user_journey.md`).

---

## Project overview

Reproducible **Qwen3.8-Flash-Next-NVFP4** on **DGX Spark** and **RTX PRO 6000** (1–8 GPUs, single node; bare-metal Docker or native-in-vLLM). Operator UX is `just` via `mise`. Recipe IDs: `qwen3-8-flash-next/{spark,rtx-6000-pro}` (see `CONTEXT.md`).

---

## Project structure

- `recipes/qwen3-8-flash-next/spark/` — PLE mmap Compose path
- `recipes/qwen3-8-flash-next/rtx-6000-pro/` — unified RTX PRO 6000 (docker + native modes, profiles, RunPod guide in README)
- `scripts/lib/` — shared `load_env`, `config_env`, `weights`, `resolve_serve`, `rtx_serve`, `docker_nct`, `pacman_progress`, `recipe_common`
- `scripts/ensure_mise.sh` — auto-install mise when missing (also invoked by bootstrap Worker)
- Reserved skeleton dirs (`hosts/`, `topologies/`, `runtimes/`, `models/`, …) — unpopulated (`.gitkeep` only)
- `.env` / `.runtime.env` / `.run/` — gitignored local state

---

## Development workflow

```text
just mise → just install → edit recipe/scripts → static checks on edited *.sh
→ just doctor → (on host) just setup / deploy / probe
→ optional just benchmark → report commands + outcomes
```

Prove recipe deploy on a clone **before** debugging distribution (`CONTEXT.md` Problem A vs B).

---

## Setup & build

```bash
cd scripts/local-ai
just mise          # or: bash scripts/ensure_mise.sh
just install       # mise + mise install (just + jq (+ locked tools); NOT CUDA/vLLM/weights)
just config        # creates .env 0600; prefers injected HF_TOKEN / VLLM_API_KEY over blank .env
just setup         # pinned image + weights; idempotent
```

Lifecycle: `just doctor | probe | benchmark | setup | deploy | status | logs | stop` (Justfile thin — logic in scripts). Troubleshoot: `benchmark-load`, `gpu`, `snapshot`.

**HF auth:** `local_ai_resolve_hf_token` prefers non-empty process env (`HF_TOKEN` → `HUGGING_FACE_HUB_TOKEN` → `RUNPOD_SECRET_HF_TOKEN`) over `.env`. Blank `HF_TOKEN=` never clobbers a Secret. Never print token values; doctor shows present/absent only. Do not copy provider Secrets into `.env`.

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

- Secrets only via env / `.env`; never echo `VLLM_API_KEY` / `HF_TOKEN` or logs bearing `--api-key`.
- Never commit `.env` / `.runtime.env`.
- 1× Spark SoT is **PLE mmap** — stock `vllm/vllm-openai:qwen38-flash-next` OOMs (~121 GiB); do not treat stock full-residency as the Spark path.
- This pass: do not reintroduce llmux as required path or an external bench-matrix harness unless the user asks.
- Stay inside `scripts/local-ai/` for implementation; report failed commands — do not guess results.
- Artifact packaging must not include weights, `.env`, credentials, logs, caches (see `CONTEXT.md`).

---

## Gotchas

- RTX RunPod: `rtx_prefer_volume_cache` uses writable `RTX_VOLUME_ROOT` when set (e.g. `/workspace-global`), else `/workspace`, else `/runpod-volume`; explicit `HF_*` / `VLLM_CACHE_ROOT` win. `RTX_VOLUME_ROOT` is **opt-in only**.
- Image: refuse `vllm/vllm-openai:latest` — pin `qwen38-flash-next` (or digest). Doctor fails closed on `:latest`.
- 1× RTX PRO 6000: profile is **conservative bring-up** (CTX 16384, low SEQS, batched 4096, prefix off) + `VLLM_PLE_CPU_OFFLOAD=1`. On purpose-built `vllm/vllm-openai:qwen38-flash-next` (`0.1.dev*+g…`) that env **is** recognized; wrong image (`:latest`) takes a BF16 PLE path and OOMs ~95 GiB. Generic `--cpu-offload-gb` is **not** the Qwen3.8 strategy. Claim 1× green only after `/v1/models` + probe on the pinned image.
- FUSE/geesefs global volumes: snapshot paths may lstat 0-byte while blobs are intact — doctor warns when detectable.
- 1× Spark SoT defaults: `CTX=65536`, `SEQS=2`, `MAX_NUM_BATCHED_TOKENS=8192`, `GPU_MEM=0.75`, `PREFIX_CACHE=1`, PLE mmap, MTP off. Batched tokens ≠ output limit. IDE presets: `CLIENT_CONTEXT=65536`, `CLIENT_OUTPUT=16384`, reasoningEffort `low` — see `recipes/qwen3-8-flash-next/spark/docs/client-side-config.md`. Cold prefill ~2.5K tok/s; decode ~17 tok/s; prefix hits ~0.5–1s TTFT.
- Keep `prompt_tokens + max_tokens ≤ CTX`. Raise `SEQS` before concurrency sweeps or aggregate tok/s flatlines.
- 2× Spark: prefer two independent TP1 replicas (same 1× recipe each) unless you need >64K / more KV on one request (then TP2 — measure first).
