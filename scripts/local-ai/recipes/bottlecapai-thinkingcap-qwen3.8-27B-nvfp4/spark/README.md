# bottlecapai-thinkingcap-qwen3.8-27B-nvfp4 / spark

Dense NVFP4 serve for [bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4](https://huggingface.co/bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4) on 1× DGX Spark (GB10). OpenAI-compatible vLLM endpoint on port **8000** (exclusive with other Spark recipes — stop the other first).

| Who owns what | |
|---------------|--|
| This recipe | Just scripts, Compose, `config/serve.env`, doctor / setup / deploy |
| Serve image (day-1 pin) | `ghcr.io/styles01/qwen38-mtp3:latest` |
| Weights | Hugging Face **gated** ThinkingCap NVFP4 (~weight-only NVFP4A16) |
| GPU | GB10 / Spark unified memory (~121 GiB usable) |

**ThinkingCap** is BottleCap AI’s efficiency-oriented Qwen3.8-27B fine-tune (not abliterated). Native MTP speculative decoding; day-1 defaults enable MTP and `--kv-cache-dtype fp8`.

---

## License & access

- **Weights:** PolyForm Small Business 1.0.0 + BottleCap personal-use grant — accept on Hugging Face before download.
- **Upstream base:** Apache-2.0 (Qwen3.8-27B lineage).
- **Gated repo:** `HF_TOKEN` (or equivalent) required; doctor/setup fail closed without it.

---

## Prerequisites

### Hugging Face (gated)

1. `just config` (creates `scripts/local-ai/.env` mode `0600`), or
2. Export `HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` / `RUNPOD_SECRET_HF_TOKEN`

### API key

`VLLM_API_KEY` required for deploy and probe.

### Port 8000

```bash
RECIPE=recipes/qwen3-8-flash-next/spark just stop
```

---

## Quick start

```bash
export RECIPE=recipes/bottlecapai-thinkingcap-qwen3.8-27B-nvfp4/spark
just doctor && just setup && just deploy && just probe
```

---

## Production defaults (spark-1x)

| Knob | Value | Notes |
|------|------:|-------|
| `CTX` | 262144 | Native window; needs GB10 + long-context env |
| `SEQS` | 4 | Conservative first boot |
| `GPU_MEM` | 0.75 | UMA headroom |
| `MTP` | 3 | `--speculative-config` draft tokens |
| Prefix cache | ON | |
| KV cache | `fp8` | `PASS_KV_DTYPE=1` |
| Quantization | from `config.json` | Do not pass `--quantization` |

Served name: **`ThinkingCap-Qwen3.8-27B`**. Parsers: `--reasoning-parser qwen3`, `--tool-call-parser qwen3_coder`, `--enable-auto-tool-choice`, `--trust-remote-code`.

**Multi-GPU (not packaged):** prefer `--data-parallel-size` with one full replica per GPU/host; TP=2 is tolerable, larger TP usually slower.

---

## Lifecycle

| Command | Role |
|---------|------|
| `just doctor` | Readiness (HF token, weights, image, port) |
| `just setup` | Gated HF download + `docker pull` |
| `just deploy` | `.runtime.env` + compose up + wait `/v1/models` |
| `just probe` | Authenticated completion |
| `just status` / `logs` / `stop` | Ops |

Base URL: `http://127.0.0.1:8000/v1` with `Authorization: Bearer $VLLM_API_KEY`.
