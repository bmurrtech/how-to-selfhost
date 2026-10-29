# local-ai — Qwen3.8-Flash-Next NVFP4 (mise + just)

Multi-target cookbook: **DGX Spark** and **RTX PRO 6000** (1–8 GPUs, one node; bare-metal Docker or native-in-vLLM).

## Install on a host

```bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark@beta" | bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | bash
```

`@beta` → catalog `rc` → **`0.0.1-rc2`**. Architecture: [`CONTEXT.md`](../../CONTEXT.md). Distro: [`guides/how-to_distro_cloudflare_github.md`](../../guides/how-to_distro_cloudflare_github.md). Changelog: [`CHANGELOG.md`](../../CHANGELOG.md).

## Pick a target / deploy path

| Deploy | Install recipe | Where the how-to lives |
|--------|----------------|------------------------|
| **DGX Spark / GB10** | `qwen3-8-flash-next/spark` | Tree + how-to: [`spark/README.md`](recipes/qwen3-8-flash-next/spark/README.md) (PLE mmap, **64K** production default). Agent notes: [`AGENTS.md`](AGENTS.md). |
| **RTX PRO 6000 — bare metal** | `qwen3-8-flash-next/rtx-6000-pro` | [`rtx README → Bare metal`](recipes/qwen3-8-flash-next/rtx-6000-pro/README.md#bare-metal) |
| **RTX PRO 6000 — [RunPod](https://runpod.io?ref=k2vwrktx)** | same recipe ID | [`rtx README → RunPod`](recipes/qwen3-8-flash-next/rtx-6000-pro/README.md#runpod) (template, Secrets, SSH **22**, volumes) |

One RTX tarball covers metal **and** RunPod (`EXEC_MODE=docker|native`). Upstream image only: `vllm/vllm-openai:qwen38-flash-next`. **Multi-node** packaging is reserved — not in this release.

**RunPod storage (short):** container disk is OS-only (≈50–80 GB). Put weights on the Pod volume (`/workspace`, ≥200 GB) by default. For frequent Pod tear-down without re-downloading weights, attach a global/network store and set `RTX_VOLUME_ROOT` (details in the [RunPod section](recipes/qwen3-8-flash-next/rtx-6000-pro/README.md#runpod)).

```bash
cd scripts/local-ai
RECIPE=recipes/qwen3-8-flash-next/rtx-6000-pro just doctor
```

## After install

```bash
cd ~/mycmd/qwen3-8-flash-next/<target>
# Bootstrap installs mise when missing; fallback:
#   bash scripts/ensure_mise.sh && mise install
just config
```

| Command | What it does |
| --- | --- |
| `just mise` / `just install` | Install mise if missing; `install` also runs `mise install` |
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

## Spark defaults (1×)

**Production:** `CTX=65536`, `SEQS=2`, batched `8192`, `GPU_MEM=0.75`, prefix **on**, PLE mmap, MTP off. IDE advertise: context `65536`, output `16384`, reasoning `low` ([client guide](recipes/qwen3-8-flash-next/spark/docs/client-side-config.md)). Decode ~17 tok/s; cold prefill ~2.5K tok/s. Full how-to: [spark README](recipes/qwen3-8-flash-next/spark/README.md).

## RTX defaults

**1×:** conservative bring-up (`CTX=16384`, low `SEQS`, batched `4096`, prefix off, `VLLM_PLE_CPU_OFFLOAD=1`). **4×+:** push-limit profiles. Dial via interactive prompts or env. Full host setup: [rtx recipe README](recipes/qwen3-8-flash-next/rtx-6000-pro/README.md).

## Client: Kilo Code (VS Code) or any OpenAI base URL

Point an OpenAI-compatible client at the running recipe. The API `model` string must match vLLM `--served-model-name` (not a friendly alias).

### Prerequisites

1. Deploy a recipe (`just setup` → `just deploy`) so port **8000** serves `/v1`.
2. Set `VLLM_API_KEY` in `scripts/local-ai/.env` (same value the server uses).
3. From your workstation, reach the host: `http://<host>:8000/v1`.

### Find the served model name

```bash
curl -fsS -H "Authorization: Bearer $VLLM_API_KEY" \
  "http://<host>:8000/v1/models"
```

Use the JSON `data[].id` value. Examples:

| Recipe | Typical `id` |
|--------|----------------|
| ThinkingCap NVFP4 | `ThinkingCap-Qwen3.8-27B` |
| Qwen3.8 Flash-Next | check `/v1/models` (recipe-specific) |

Or read `SERVED_MODEL_NAME` in that recipe’s `config/serve.env`.

### Configure Kilo Code

**UI**

1. Open Kilo **Settings** → **Providers**.
2. Add or edit a custom **OpenAI Compatible** provider.
3. Set **Base URL** to `http://<host>:8000/v1`.
4. Set **API key** to the same value as `VLLM_API_KEY`.
5. Add a model whose id equals the served name from the table above.
6. Select that model, then send a short chat.

**Config file**

- Linux/macOS: `~/.config/kilo/kilo.jsonc`
- Windows: `%USERPROFILE%\.config\kilo\kilo.jsonc`

Use the served name as the models map key and as `modelID`. Kilo may ignore a friendly key and send that key to the API unchanged.

```jsonc
{
  "model": "my-ai/ThinkingCap-Qwen3.8-27B",
  "provider": {
    "my-ai": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://<host>:8000/v1",
        "apiKey": "<VLLM_API_KEY>"
      },
      "models": {
        "ThinkingCap-Qwen3.8-27B": {
          "name": "ThinkingCap Qwen3.8 27B",
          "modelID": "ThinkingCap-Qwen3.8-27B",
          "limit": { "context": 65536, "output": 16384 }
        }
      }
    }
  }
}
```

Restart Kilo after you save the file.

### Other OpenAI-compatible clients

Set:

- Base URL: `http://<host>:8000/v1`
- API key: `VLLM_API_KEY`
- Model: exact `data[].id` from `/v1/models`

### Verify

```bash
curl -fsS -H "Authorization: Bearer $VLLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"ThinkingCap-Qwen3.8-27B","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' \
  "http://<host>:8000/v1/chat/completions"
```

Expect HTTP **200** and a completion payload.

### If that fails

| Symptom | Check |
|---------|--------|
| **401** `Unauthorized` | Client API key must match server `VLLM_API_KEY`. Prefer `Authorization: Bearer …`. Restart the client after changing keys. |
| **404** model does not exist | Client sent a wrong `model` string. Align it with `/v1/models` `id`. |
| Connection refused | Recipe not deployed, wrong host/port, or firewall. On the GPU host run `just status`. |
