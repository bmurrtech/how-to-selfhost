# local-ai — Qwen3.8-Flash-Next NVFP4 (mise + just)

Multi-target cookbook: **DGX Spark** and **RTX PRO 6000** (1–8 GPUs, one node; bare-metal Docker or native-in-vLLM).

## Install on a host

```bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark@beta" | sh
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | sh
```

`@beta` → catalog `rc` → **`0.0.1-rc2`**. Architecture: [`CONTEXT.md`](../../CONTEXT.md). Distro: [`guides/how-to_distro_cloudflare_github.md`](../../guides/how-to_distro_cloudflare_github.md). Changelog: [`CHANGELOG.md`](../../CHANGELOG.md).

## Targets

| Recipe ID | When | Notes |
|-----------|------|--------|
| `qwen3-8-flash-next/spark` | DGX Spark / GB10 | Community PLE **mmap** image |
| `qwen3-8-flash-next/rtx-6000-pro` | RTX PRO 6000 metal **or** RunPod | Upstream `vllm/vllm-openai:qwen38-flash-next`; coarse `EXEC_MODE=docker\|native`. See recipe [README](recipes/qwen3-8-flash-next/rtx-6000-pro/README.md) |

**Multi-node** packaging is reserved — not in this release. No project-owned Docker Hub image.

```bash
cd scripts/local-ai
RECIPE=recipes/qwen3-8-flash-next/rtx-6000-pro just doctor
```

## After install

```bash
cd ~/mycmd/qwen3-8-flash-next/<target>
mise install   # optional if tools already present
just config
```

| Command | What it does |
| --- | --- |
| `just doctor` (`check`) | Hardware / runtime / config sanity → `RESULT: PASS\|WARN\|FAIL` |
| `just config` / `--show` | Ensure `.env` + knobs, or resolved config only (no secrets) |
| `just probe` | One chat completion: HTTP + TTFT + latency + expect match |
| `just benchmark` | Fixed `vllm bench serve` (4096/256/50 @ 2 rps) |
| `just benchmark-load` | Same bench at 1 / 4 / 8 rps |
| `just gpu` / `gpu-watch` | `nvidia-smi` evidence |
| `just logs [error\|cuda\|oom\|vllm]` | Tail or filter logs |
| `just snapshot` | Redacted bundle under `.run/snapshot-*` |
| `just setup` / `deploy` / `status` / `stop` / `token` | Lifecycle |

Daily loop: `just doctor` → `just probe` → `just benchmark`.

## RTX push-limit defaults

`max-model-len=auto`, `max-num-batched-tokens=8192`, `max-num-seqs=256`, `gpu-memory-utilization=0.95`, TP=GPU count, prefix-caching + marlin. Dial down via interactive prompts or `.env`.

## RunPod disk

Default **30 GB** container disk is too small. Prefer ≥**200 GB** or persistent volume for HF cache. Recommended Start CMD: `sleep infinity` so the recipe owns deploy. Details in the rtx recipe README.
