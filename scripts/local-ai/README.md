# local-ai — Qwen3.8-Flash-Next NVFP4 on DGX Spark (mise + just)

## Install on a host (recommended)

```bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark?channel=rc" -o mycmd-install.sh
less mycmd-install.sh
bash mycmd-install.sh
```

One-liner: `curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark?channel=rc" | sh`

Channel `rc` currently resolves to GitHub Release **v0.0.1-rc1** (no stable channel yet). Architecture: root [`CONTEXT.md`](../../CONTEXT.md).

## After install

```bash
cd ~/mycmd/qwen3-8-flash-next/spark   # default; installer prints the path
cp .env.example .env && chmod 600 .env   # set VLLM_API_KEY, HF_TOKEN
mise install
just check
just setup    # idempotent: weights + pinned PLE mmap image
just deploy
just status
just benchmark
just stop
```

Recipe: `recipes/qwen3-8-flash-next/spark/` (`recipe.yaml`, `compose.yaml`, `config/serve.env`).

Knobs: `config/serve.env` defaults; override in `.env` or shell. Secrets only in `.env`.
