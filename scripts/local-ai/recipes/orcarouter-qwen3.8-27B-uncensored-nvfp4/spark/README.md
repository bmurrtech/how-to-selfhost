# orcarouter-qwen3.8-27B-uncensored-nvfp4 / spark

Dense NVFP4 serve for [orcarouter/Qwen3.8-27B-Uncensored-NVFP4](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-NVFP4) on 1× DGX Spark (GB10). OpenAI-compatible vLLM endpoint on port **8000** (exclusive with `qwen3-8-flash-next/spark` — stop the other recipe first).

| Who owns what | |
|---------------|--|
| This recipe | Just scripts, Compose, `config/serve.env`, doctor / setup / deploy |
| Serve image (day-1 pin) | `ghcr.io/styles01/qwen38-mtp3:latest` (swap for NVIDIA Spark recipe image when available) |
| Weights | Hugging Face gated checkpoint (~23 GiB NVFP4 on disk) |
| GPU | GB10 / Spark unified memory (~121 GiB usable) |

**Abliterated model — use with caution.** This checkpoint had safety alignment substantially removed. It is intended as a frontier cybersecurity model (successor to OrcaCyber Zero 1.0), post-trained for **authorized** security research and engineering: vulnerability research, exploit development, penetration testing, security auditing, and multi-step cyber reasoning — with long context, native tool calling, and structured outputs.

Vendor-reported evaluations (see HF card): 95.8% evaluable CVE-Bench subset, 100% Cybench (unrestricted agent execution), 76.5% SWE-bench Pro V2, 93.9% HumanEval+.

---

## Disclaimer — read before use

This model has had its safety alignment substantially removed via abliteration (orthogonalizing the refusal direction out of the residual stream). As a direct consequence:

- It will comply with harmful, unethical, offensive, or illegal requests that the original Qwen3.8-27B would refuse. It has no meaningful built-in guardrails.
- It is released strictly for legitimate research — interpretability, AI-safety and refusal-mechanism study, red-teaming, robustness evaluation, and controlled experiments.
- You assume full responsibility and liability for how you use it and for everything it generates. Do not deploy it to end users or in production without adding your own safety, moderation, and abuse-prevention layers.
- Use must comply with the Apache 2.0 License inherited from the base model, and all laws and regulations that apply to you.
- The authors and uploaders accept no liability for any misuse or harm arising from this model. Its outputs do not reflect the views of the uploaders or of Qwen / Alibaba.

**By downloading or using this model you acknowledge and accept the above.**

### Intended use

- Research into refusal mechanisms, alignment, and interpretability.
- Red-teaming and safety / robustness evaluation in controlled environments.
- Uncensored generation for authorized, lawful research settings.

### Out of scope

- Any use that violates the base model's Apache 2.0 license or applicable law.
- Deployment to the public or to end users without additional safety and moderation layers.
- Generating content intended to harm, harass, defraud, or endanger people.

---

## Prerequisites

### Hugging Face (gated)

Accept the model license on Hugging Face, then provide a token **before** `just setup` or `just doctor`:

1. `just config` (creates `scripts/local-ai/.env` with mode `0600`), or
2. Export one of:
   - `HF_TOKEN`
   - `HUGGING_FACE_HUB_TOKEN`
   - `RUNPOD_SECRET_HF_TOKEN` / host Secret injection (RunPod, K8s, etc.)

Doctor and setup **fail closed** if no token is present. Values are never printed in logs.

### API key

`VLLM_API_KEY` is required for deploy and probe (OpenAI-compatible auth on localhost).

### Port 8000

Only one Spark recipe should bind `:8000`. Stop flash-next first:

```bash
RECIPE=recipes/qwen3-8-flash-next/spark just stop
```

---

## Quick start

From `scripts/local-ai/` on the Spark host:

```bash
export HF_TOKEN=hf_…          # or set in .env via just config
export VLLM_API_KEY=…         # or set in .env

RECIPE=recipes/orcarouter-qwen3.8-27B-uncensored-nvfp4/spark just doctor
RECIPE=recipes/orcarouter-qwen3.8-27B-uncensored-nvfp4/spark just setup
RECIPE=recipes/orcarouter-qwen3.8-27B-uncensored-nvfp4/spark just deploy
RECIPE=recipes/orcarouter-qwen3.8-27B-uncensored-nvfp4/spark just probe
```

Shorter override once per shell:

```bash
export RECIPE=recipes/orcarouter-qwen3.8-27B-uncensored-nvfp4/spark
just doctor && just setup && just deploy && just probe
```

Default `Justfile` recipe remains `qwen3-8-flash-next/spark`; always set `RECIPE=` for this model.

---

## Production defaults (spark-1x)

| Knob | Value | Notes |
|------|------:|-------|
| `CTX` / `--max-model-len` | 262144 | Card intent; needs GB10 + long-context env |
| `SEQS` | 4 | Conservative vs card (96) for first boot |
| `GPU_MEM` | 0.75 | UMA headroom on Spark |
| `MTP` | 2 | `--speculative-config` draft tokens |
| Prefix cache | ON | |
| `MAX_NUM_BATCHED_TOKENS` | 8192 | |
| `SHM_SIZE` | 16g | |
| Quantization | from `config.json` | **Do not** pass `--quantization` |
| KV cache dtype | omitted | Set `PASS_KV_DTYPE=1` in `.env` to pass `--kv-cache-dtype fp8` |

Served OpenAI model name: **`Qwen3.8-27B-Uncensored`**. Full VL stack (no `--language-model-only`).

Parsers: `--reasoning-parser qwen3`, `--tool-call-parser qwen3_coder`, `--enable-auto-tool-choice`, `--trust-remote-code`.

---

## Usage (clients)

### Self-host (this recipe)

Base URL: `http://127.0.0.1:8000/v1` with `Authorization: Bearer $VLLM_API_KEY`.

**Thinking toggle** (Qwen3.8 default on):

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:8000/v1", api_key=os.environ["VLLM_API_KEY"])

resp = client.chat.completions.create(
    model="Qwen3.8-27B-Uncensored",
    messages=[{"role": "user", "content": "Prove that sqrt(2) is irrational."}],
    extra_body={"chat_template_kwargs": {"enable_thinking": True}},
)
print(resp.choices[0].message.reasoning)
print(resp.choices[0].message.content)
```

**Tool calling:** standard OpenAI `tools` + `tool_calls` + `role: tool` multi-turn (parsed by `qwen3_coder`).

### OrcaRouter hosted (no self-host)

OpenAI-compatible gateway at [orcarouter.ai](https://orcarouter.ai) — model id `qwen/qwen3.8-27b`, 262K context, tools + reasoning.

---

## Hardware notes

- **NVFP4 layers** need Blackwell (B200 / GB200 / GB10 / RTX 50-series) for native FP4 tensor cores; FP8 layers run on Hopper+.
- Weights ~23 GiB vs ~56 GiB BF16; full 262K context still needs substantial KV cache (checkpoint stores KV scheme in FP8 in `config.json`).
- This recipe does **not** use flash-next PLE mmap or blazux image build — dense load from HF cache mount.

GB10 compose/runtime env includes `FLASHINFER_CUDA_ARCH_LIST=12.1a`, `FLASHINFER_DISABLE_VERSION_CHECK=1`, `VLLM_ALLOW_LONG_MAX_MODEL_LEN=1`, `TORCH_CUDA_ARCH_LIST=12.1a`.

---

## Lifecycle commands

| Command | Role |
|---------|------|
| `just doctor` | Readiness (HF token, weights, image, port) + abliteration banner |
| `just setup` | Gated HF download + `docker pull` (retries) |
| `just deploy` | Write `.runtime.env`, compose up, wait for `/v1/models` |
| `just probe` | One authenticated completion |
| `just status` / `just logs` / `just stop` | Ops |

---

## License

Apache 2.0 (base Qwen3.8-27B). Abliteration and quantization do not remove license obligations.
