# local-ai — Qwen3.8-Flash-Next NVFP4 on DGX Spark (mise + just)

```bash
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
