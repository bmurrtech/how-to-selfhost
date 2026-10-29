# qwen3-8-flash-next / spark

Qwen3.8-Flash-Next NVFP4 on 1× DGX Spark (GB10) via the PLE mmap vLLM image.

| Who owns what | |
|---------------|--|
| This tarball | Just recipes, Compose, `config/serve.env`, check / setup / deploy |
| Serve image | `qwen38-flash-dgx:c578815` ([blazux/qwen3.8-Flash-DGX](https://github.com/blazux/qwen3.8-Flash-DGX) @ `c578815…`) |
| Weights | Hugging Face `nvidia/Qwen3.8-Flash-Next-NVFP4` (~124G on disk) |
| GPU / unified RAM | Your Spark (~121 GiB usable of ~128 GB) |

---

## Why this recipe exists

### Stock image OOMs

`vllm/vllm-openai:qwen38-flash-next` never reaches `/v1/models`. Docker exits `137` with `OOMKilled=true`. Peak unified RAM hits ~112 GiB on a ~121 GiB machine.

The NVFP4 checkpoint is ~124–126 GiB on disk; ~48 GiB of that is the FP8 PLE / n-gram table. Stock vLLM keeps the table resident with the MoE/attention weights, so unified memory has nothing left for a useful serve. Lowering `--gpu-memory-utilization` does not help: that knob budgets KV after weights load. `VLLM_PLE_CPU_OFFLOAD=1` also fails here because CPU and GPU share one pool on Spark.

This recipe uses the community PLE mmap image instead. Resident weights drop to ~76 GiB; the ~48 GiB table stays on NVMe and is gathered per token. Env: `VLLM_PLE_MMAP=1`, workers `32`, `MADVISE=random`, prewarm `0`. Keep `GPU_MEM=0.75` so page-cache / UMA headroom remains for mmap.

### Client asks for more tokens than the server allows

On an early 16K serve, a client requested `max_tokens=32000` against `--max-model-len 16384`. vLLM rejected it:

```text
max_tokens=32000 > max_model_len=16384
```

Auth, networking, and the model name were fine. Kilo and OpenCode often default unknown custom models to 32K output unless you set `limit.context` and `limit.output`.

This recipe ships a 64K server ceiling. Client presets: context `65536`, output `16384`, reasoning effort `low`. Still enforce `prompt_tokens + max_tokens ≤ CTX`. Full client setup: [`docs/client-side-config.md`](docs/client-side-config.md).

### 16K was a first smoke, not the production shape

First bring-up used `--max-model-len 16384` and prefix-cache off because that was the only measured config. Later benches showed 64K holds up for coding request shapes, so 64K + prefix caching are the defaults now.

---

## Production defaults (spark-1x)

| Knob | Value | Role |
|------|------:|------|
| `--max-model-len` / `CTX` | 65536 | Combined input+output ceiling per request |
| `--max-num-seqs` / `SEQS` | 2 | Concurrent sequences (1–2 users / agents) |
| `--max-num-batched-tokens` | 8192 | Scheduler batch size (not a generation limit) |
| `--gpu-memory-utilization` | 0.75 | UMA / page-cache headroom for mmap |
| Prefix caching | ON | Reuse stable system/tool/repo prefixes |
| PLE | mmap (~47.7 GiB on disk) | Required on 1× Spark |
| MTP | OFF | No bench evidence to enable yet |
| TP | 1 | Single node |

Leave `GPU_MEM` at 0.75; mmap needs headroom. `8192` batched tokens is not “max output is 8K.”

### Benchmark (2026-09-18) — what the tok/s feel like

Config: `CTX=65536` `SEQS=2` batched `8192` util `0.75` PLE mmap MTP off. Image `qwen38-flash-dgx:c578815`. Boot ~11 min (652s). Smoke PASS; no OOM.

**Decode** stays ~17 tok/s (ITL ~59 ms) from empty context through 60K. Two concurrent short streams can sum ~27–34 tok/s. Short-context regression vs the old 16K server is under ~5%.

**Prefill (cold)** is flat at ~2.5–2.6K prompt tok/s, so TTFT grows linearly with prompt size (`TTFT ≈ tokens / 2550`). That is the 1× Spark + PLE mmap tax (n-gram table gathered from NVMe). Raising the 64K ceiling did not slow prefill per token; larger prompts just wait longer.

| Cold prompt size | TTFT | Prompt tok/s | Interactive feel |
|-----------------:|-----:|-------------:|------------------|
| 8K | ~3.3s | ~2500 | Normal turn |
| 16K | ~6.3s | ~2600 | Acceptable |
| 32K | ~12.6s | ~2600 | Occasional large turn only |
| 48K | ~19s | ~2580 | Too slow as a habit |
| 60K | ~24s | ~2560 | Capacity / emergency |

**Prefix cache** (production ON) is the big UX win on stable prefixes (~21.5K shared):

| | TTFT | Effective prompt rate |
|--|-----:|----------------------:|
| Cache OFF (every turn cold) | ~8.3s | ~2580 tok/s |
| Cache ON, after first fill | ~0.62s | ~35K tok/s (~13×) |

8K / 16K / 32K prefix hits after warm-up: TTFT ~0.4–0.6s. Changing bulk context (huge pasted files) still pays the cold ~2.5K tok/s rate.

### Coding-turn time estimates (wall clock)

Decode at ~17 tok/s. Cold prefill at ~2.5K tok/s. Prefixed turns after warm-up: TTFT ~0.5–1s on the stable prefix.

| Kind of turn | Prompt (approx) | Output | Prefill wait | Decode wait | Total ≈ |
|--------------|----------------:|-------:|-------------:|------------:|--------:|
| Short agent turn (prefix hit) | 8K stable + small delta | 1K | ~0.5–1s | ~60s | ~1 min |
| Typical coding turn (prefix hit) | 8–16K stable + delta | 2–4K | ~0.5–1s | ~2–4 min | ~2–4 min |
| Cold mid-size paste (no hit) | 16K new | 2K | ~6s | ~2 min | ~2 min |
| Cold large paste | 32K new | 4K | ~13s | ~4 min | ~4.5 min |
| Near-ceiling (avoid as habit) | 48K new | 4K | ~20s | ~4 min | ~4.5 min |
| Capacity check (measured PASS) | ~52K in / 8K out | 8K | ~20s | ~8 min | ~8.5 min |

Rule of thumb: keep normal multi-turn loops on a fixed system/tools/repo prefix with prefix cache ON; compact or hand off around 40–48K; treat 48–60K as emergency capacity, not the everyday turn size. Advertise client output `16384` (not 32K); keep `prompt + output ≤ 65536`. See [`docs/client-side-config.md`](docs/client-side-config.md).

---

## Quick start

```bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark@beta" | bash
cd ~/mycmd/qwen3-8-flash-next/spark   # path may vary after extract
# Bootstrap installs mise when missing; otherwise:
#   bash scripts/ensure_mise.sh && mise install
just config          # creates scripts/local-ai/.env (0600); set VLLM_API_KEY, HF_TOKEN
just doctor
just setup           # image + weights (idempotent)
just deploy
just probe
```

Lifecycle: `just status` · `just logs` · `just benchmark` · `just gpu` · `just snapshot` · `just stop` · `just token`.

Knobs live in [`config/serve.env`](config/serve.env). Override via `scripts/local-ai/.env` or shell exports (precedence: serve.env < `.env` < non-empty shell).

---

## Server capacity vs client policy

These are different numbers — do not collapse them:

| Concept | Default | Meaning |
|---------|--------:|---------|
| Hardware/runtime ceiling (`CTX`) | 65536 | `input + output ≤ 65536` for one request |
| Scheduler batch size | 8192 | Tokens scheduled per iteration (not a generation limit) |
| Client `limit.output` | 16384 | Room for reasoning + answer inside the 64K sequence |
| Client reasoning | `low` | Default effort; use `medium` / `xhigh` when needed |

```bash
# Server (consumed by resolve_serve / compose)
CTX=65536
SEQS=2
MAX_NUM_BATCHED_TOKENS=8192
GPU_MEM=0.75
PREFIX_CACHE=1

# Client advertising (not a hardware limit)
CLIENT_CONTEXT=65536
CLIENT_OUTPUT=16384
```

`16384` is not “65K prompt + 16K output.” It tells the IDE to reserve enough of the combined 64K budget for generation. An `8192` advertise fixed the 32K overflow bug but was too tight for Qwen reasoning (agent hit output limit while thinking). Never leave output unset (clients often fall back to 32000).

Full guide (Kilo paths, reasoning variants, OpenCode, troubleshooting, compaction): [`docs/client-side-config.md`](docs/client-side-config.md).

### Kilo Code (tested)

Provider OpenAI Compatible. Base URL `http://<SPARK-IP-OR-HOSTNAME>:8000/v1`. Model `qwen3.8-flash-next`. Config file: `~/.config/kilo/kilo.jsonc` (Windows: `%USERPROFILE%\.config\kilo\kilo.jsonc`).

```json
{
  "$schema": "https://app.kilo.ai/config.json",
  "model": "my-ai/qwen3.8-flash-next",
  "disabled_providers": [],
  "provider": {
    "my-ai": {
      "name": "DGX Spark",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://<SPARK-IP-OR-HOSTNAME>:8000/v1"
      },
      "models": {
        "qwen3.8-flash-next": {
          "name": "Qwen 3.8 Flash Next",
          "tool_call": true,
          "limit": {
            "context": 65536,
            "output": 16384
          },
          "options": {
            "reasoningEffort": "low"
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "xhigh": { "reasoningEffort": "xhigh" }
          }
        }
      }
    }
  }
}
```

Omit Kilo `"reasoning": true` for this deployment; drive thinking via `reasoningEffort` instead. Put the API key in env / Kilo secrets — not in the JSON if you can avoid it. Replace `<SPARK-IP-OR-HOSTNAME>` with the Spark LAN name or IP (`127.0.0.1` only if the IDE runs on the Spark).

---

## Manual `docker run` (same production shape)

What Compose resolves from `serve.env` (PLE mmap image required):

```bash
HF_CACHE=${HF_CACHE:-$HOME/.cache/huggingface}
MODEL=nvidia/Qwen3.8-Flash-Next-NVFP4
REPO_DIR="$HF_CACHE/hub/models--${MODEL//\//--}"
REV=$(cat "$REPO_DIR/refs/main" 2>/dev/null || cat "$REPO_DIR/refs/master")
SNAP_IN="/hf/hub/models--${MODEL//\//--}/snapshots/$REV"
API_KEY=${VLLM_API_KEY:?set VLLM_API_KEY}

sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
docker rm -f qwen38-nvfp4 2>/dev/null || true

docker run -d --name qwen38-nvfp4 \
  --gpus all \
  --ipc=host \
  --shm-size 16g \
  -p 8000:8000 \
  -v "${HF_CACHE}:/hf" \
  -e HF_HOME=/hf \
  -e HF_HUB_OFFLINE=1 \
  -e VLLM_PLE_MMAP=1 \
  -e VLLM_PLE_MMAP_WORKERS=32 \
  -e VLLM_PLE_MMAP_PREWARM=0 \
  -e VLLM_PLE_MMAP_MADVISE=random \
  -e VLLM_QSA_DET_TOPK=1 \
  -e VLLM_QSA_DET_LIB=/opt/llm/kernel-det/_C_det.so \
  -e VLLM_USE_FLASHINFER_SAMPLER=1 \
  qwen38-flash-dgx:c578815 \
  "${SNAP_IN}" \
  --served-model-name qwen3.8-flash-next \
  --host 0.0.0.0 \
  --port 8000 \
  --load-format safetensors \
  --max-model-len 65536 \
  --max-num-seqs 2 \
  --max-num-batched-tokens 8192 \
  --gpu-memory-utilization 0.75 \
  --enable-prefix-caching \
  --enable-chunked-prefill \
  --no-enable-flashinfer-autotune \
  --kv-cache-dtype auto \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --api-key "${API_KEY}" \
  -cc.cudagraph_mode=PIECEWISE \
  -cc.splitting_ops='["vllm::unified_attention_with_output","vllm::unified_mla_attention_with_output","vllm::mamba_mixer2","vllm::mamba_mixer","vllm::short_conv","vllm::qwen3_8_flash_next_ple_short_conv","vllm::qwen3_8_flash_next_qsa_with_output","vllm::linear_attention","vllm::qwen_gdn_attention_core","vllm::qwen_gdn_attention_core_fused_norm_packed","vllm::sparse_attn_indexer","vllm::ple_mmap_lookup"]'
```

Wait for `Application startup complete` (~8–13 min first load), then:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer ${API_KEY}" \
  http://127.0.0.1:8000/v1/models
```

---

## 2× DGX Spark

Two Sparks are not one coherent 256 GB machine.

### Default: `spark-2x-replica`

Two independent TP1 containers (each = spark-1x: 64K / seq=2 / mmap / prefix on) behind a light router (LiteLLM, nginx, etc.).

```text
API / load balancer
       /          \
  Spark A          Spark B
  TP=1 64K         TP=1 64K
  seq=2            seq=2
```

You get roughly 2× independent request capacity, failure isolation, and rolling upgrades, with no per-token TP fabric. Use this when 1× already covers your coding context need (64K).

### Optional: `spark-2x-tp`

`--tensor-parallel-size 2` over QSFP / 200GbE when one request needs more KV than one Spark leaves. Start at 64K / seq=4, then measure:

| Context | Target seqs (test points) |
|--------:|--------------------------:|
| 64K | 4 |
| 96K | 2 |
| 128K | 2 |
| 192K | 1 |
| 262K | 1 |

Skip jumping straight to 128K. TP adds interconnect cost on every forward; a second Spark does not automatically double single-stream decode.

Later experiment (not a default): TP2 full PLE residency vs TP2 + mmap. Promote full residency only if it beats mmap on TTFT, decode, and UMA pressure.

Multi-node Compose is not in this recipe yet. Wire it by hand until a dedicated topology ships.

---

## When to use something else

| Situation | Prefer |
|-----------|--------|
| 1–2 coding users, ≤64K combined context | 1× Spark (this recipe) |
| More independent agents at 64K | 2× Spark replicas |
| One request needs ≫64K or much more KV | 2× TP2 (measure), or climb CTX/YaRN carefully on 1× |
| Discrete 96 GB Blackwell + separate host RAM | RTX PRO 6000 recipe (`VLLM_PLE_CPU_OFFLOAD=1`) |
| Higher concurrent throughput / multi-GPU | 4× RTX PRO 6000 |
| Less NVMe page-cache dependence | TP2 full-residency experiment (not default) |

Validated production boundary on 1× Spark with mmap: 64K / seq=2. Native model context goes to 262K; treat anything above 64K as unproven until you re-measure under your latency SLO. Raising `CTX` further trades KV headroom and latency for longer prompts.

---

## Context and coding sessions

If a request exceeds the server ceiling, vLLM rejects it. Stuffing a noisy prompt under the ceiling is a different failure: early instructions get ignored, APIs get invented, or the wrong file gets patched.

Given cold prefill at ~2.5K tok/s:

| Cold prompt | TTFT | Use as |
|------------:|-----:|--------|
| 8K | ~3s | Normal interactive |
| 16K | ~6s | OK once prefix hits follow |
| 32K | ~13s | Occasional large turns only |
| 48K+ | ~19s+ | Compaction / emergency boundary |

With prefix hits, multi-turn loops should see ~0.5–1s TTFT on the stable prefix. That is what makes 64K useful in practice.

| Practice | Why |
|----------|-----|
| Advertise context 65536 / output 16384; `reasoningEffort: low` | Stops 32K fallback; leaves room for reasoning inside CTX — see [`docs/client-side-config.md`](docs/client-side-config.md) |
| Prefix cache ON; fixed system/tools/repo prefix; append only the delta | Proven ~13× TTFT cut on ~21.5K shared prefix |
| Retrieval (Graphify, ripgrep, focused `@file`s) over dumping the tree each turn | Avoids cold ~2.5K tok/s on huge pastes |
| Compact / hand off around 40–48K | 48–60K is capacity, not the normal turn size |
| Caveman / budget modes when chatter burns tokens | Leaves room for code under CTX |

Do not raise `gpu-memory-utilization` to “speed prefill” — that starves mmap page cache and can worsen TTFT. Changing CTX alone only raises the ceiling; it does not make prefill faster per token.

---

## Secrets and safety

- Secrets only in `.env` / env. Never commit `.env` or `.runtime.env`.
- vLLM may log `--api-key` in plaintext; treat container logs as secret-bearing.
- Do not expose raw `:8000` to the public internet without auth, TLS, or network policy.

---

## Related

- Client / Kilo / OpenCode: [`docs/client-side-config.md`](docs/client-side-config.md)
- Parent cookbook: [`../../README.md`](../../README.md)
- Agent notes: [`../../AGENTS.md`](../../AGENTS.md)
- Local design notes (gitignored): `pm/qwen-self-host/Qwen3_8_Target_Deployments.md`
