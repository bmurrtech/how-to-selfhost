# qwen3-8-flash-next / rtx-6000-pro

Run **Qwen3.8-Flash-Next** on **RTX PRO 6000** (1–8 GPUs, one node).

One recipe ID, one tarball. The same commands work on bare metal and RunPod; only the host setup differs.

| Who owns what | |
|---------------|--|
| This tarball | Just recipes, profiles, config, check, setup, deploy |
| Upstream image | `vllm/vllm-openai:qwen38-flash-next` (no project Docker Hub image) |
| Weights | Hugging Face |
| GPU / disk | Your machine or RunPod |

---

## How it decides docker vs native

| Mode | Typical host | What `just deploy` does |
|------|--------------|-------------------------|
| `docker` | Bare metal with Docker | Compose → upstream vLLM image |
| `native` | Already inside that image (usual RunPod) | `vllm serve` in-process |

Detection is automatic and idempotent:

- Inside the vLLM image (or `vllm` on PATH in a container) → **native**
- Host Docker usable otherwise → **docker**

`EXEC_MODE=docker` or `EXEC_MODE=native` is an **optional override**. You can set it in the RunPod template for clarity; if you leave it unset, deploy still picks the right path.

---

## Quick start (both hosts)

```bash
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | sh
cd ~/mycmd/qwen3-8-flash-next/rtx-6000-pro   # path may vary after extract
mise install                                 # only if just/jq missing
just config
just doctor
just setup
just deploy
just probe
```

Lifecycle after that: `just status` · `just logs` · `just benchmark` · `just gpu` · `just snapshot` · `just stop` · `just token`.

---

## Bare metal

- Ubuntu **22.04 / 24.04** recommended (Docker helpers)
- Install the NVIDIA **driver yourself** — this recipe never upgrades drivers/kernels
- `just setup` may install Docker Engine + NVIDIA Container Toolkit
- Docker path publishes the API on **127.0.0.1 only** — do not open raw `:8000` to the internet
- Keep **≥ 200 GiB** free near the Hugging Face cache for NVFP4

Secrets live in `scripts/local-ai/.env` (created by `just config`, mode `0600`). Prefer that over putting tokens in the shell history.

---

## RunPod

**Idea:** RunPod gives you the GPU and the official vLLM image. This tarball owns config → check → setup → deploy. The Pod should start in an **idle shell**, not already serving a model.

### Step 1 — create or edit the template

1. Deploy → **Pods** → create a Pod (or open a saved template).
2. Search and select image **`vllm/vllm-openai:qwen38-flash-next`**.  
   Avoid PyTorch 2.2 Jupyter and `vllm/vllm-openai:latest`.
3. Click the **Edit** control (**pencil**). Selecting the image alone is not enough — you must edit the fields below.

| Field | Value |
|-------|--------|
| Name | e.g. `qwen3-8-flash-next-rtx-6000-pro` |
| Container image | `vllm/vllm-openai:qwen38-flash-next` (pin a digest when you have one; see `recipe.yaml`) |
| CUDA host | ≥ 13.0 |
| GPU | RTX PRO 6000 × **1–8**, same node |
| Container disk | **50–80 GB** — OS/runtime only. Erased when the Pod stops. **Do not** put the model cache here. |
| Volume disk | **≥ 200 GB** (start at **250 GB**) for weights, PLE data, compile cache, download headroom |
| Volume mount path | **`/workspace`** (Pod default) |
| Expose HTTP | **8000** (RunPod HTTPS proxy) |
| Expose TCP | none for Web Terminal; add **22** only if you want [SSH](https://docs.runpod.io/pods/configuration/use-ssh) / [VS Code or Cursor](https://docs.runpod.io/pods/configuration/connect-to-ide) |
| **Env vars** | Non-secret knobs — see copy-paste block below |
| **Secrets** | `HF_TOKEN` and preferably `VLLM_API_KEY` — [Manage secrets](https://docs.runpod.io/pods/templates/secrets) |

#### Container start command (required)

The image entrypoint is `vllm serve`. If you only put `sleep infinity` in Start CMD, RunPod passes that as **arguments to `vllm serve`**, not as a shell command.

Paste this JSON into **Container start command** (overrides entrypoint + cmd):

```json
{"entrypoint":["/bin/bash"],"cmd":["-lc","sleep infinity"]}
```

You should get a Pod with CUDA / PyTorch / vLLM installed and **no model running**. Open **Web Terminal**, or connect with [SSH](https://docs.runpod.io/pods/configuration/use-ssh) / [VS Code or Cursor](https://docs.runpod.io/pods/configuration/connect-to-ide) (expose TCP **22** if you need full SSH / Remote-SSH).

**Volume tip:** the volume disk survives stop/restart but is **deleted if you terminate the Pod**. For long-lived weights across new Pods, attach a **network volume** (still mounts at `/workspace` on Pods).

#### Env vars (non-secret) — copy into the template editor

Paste into RunPod’s environment / raw editor (not the Secrets UI):

```bash
# Optional but recommended — makes intent obvious; omit to rely on auto-detect
EXEC_MODE=native

# Persist caches on the volume (Pods mount at /workspace)
HF_CACHE=/workspace/huggingface
HF_HOME=/workspace/huggingface
VLLM_CACHE_ROOT=/workspace/vllm-cache

# Optional knobs (defaults already match push-limit profiles)
# PORT=8000
# CTX=auto
# SEQS=256
# GPU_MEM=0.95
# MAX_NUM_BATCHED_TOKENS=8192
# TENSOR_PARALLEL_SIZE=   # leave unset → just config / profile sets = GPU count
# RTX_INTERACTIVE=0
# PROFILE_CONFIRM=1

# Do not set Serverless worker vars like MODEL_NAME / MAX_CONCURRENCY here —
# this recipe owns serve via just deploy. Full catalog (reference only):
# https://docs.runpod.io/serverless/vllm/environment-variables
```

| Variable | Required? | What it does |
|----------|-----------|--------------|
| `EXEC_MODE` | No | Force `native` or `docker`. Unset → auto-detect (idempotent). |
| `HF_CACHE` / `HF_HOME` | Recommended | Where weights live. Prefer `/workspace/...` so they survive restarts. |
| `VLLM_CACHE_ROOT` | Recommended | Persists vLLM compile cache across container recreates. |
| `PORT` | No | Listen port (default `8000`). |
| `CTX`, `SEQS`, `GPU_MEM`, `TENSOR_PARALLEL_SIZE`, … | No | Serve knobs; profiles / `just config` also set these. |
| `RTX_INTERACTIVE=0` | No | Skip TTY prompts (pair with `PROFILE_CONFIRM=1` for experimental GPU counts). |

> Auto-prefer: writable `/workspace` → `HF_CACHE`/`HF_HOME`=`/workspace/huggingface`, `VLLM_CACHE_ROOT`=`/workspace/vllm-cache`. Else `/runpod-volume/...` when that mount exists. Explicit env always wins.

#### Secrets (RunPod Secrets UI — not plain env)

Create and attach secrets per [Manage secrets](https://docs.runpod.io/pods/templates/secrets) (`{{ RUNPOD_SECRET_… }}` or the key-icon picker). Do **not** put them in plain template environment variables.

| Secret | Why |
|--------|-----|
| `HF_TOKEN` | Faster / authenticated Hugging Face downloads for gated or rate-limited models. Strongly recommended even when the card looks public. |
| `VLLM_API_KEY` | Bearer key for the OpenAI-compatible API. Prefer a **cryptographically random** value (~32+ bytes / 64 hex chars). Avoid short passwords and avoid relying on any predictable provider default. |

At Pod start, Secrets are injected as normal environment variables. `just config` still ensures a local `.env` (mode `0600`) for portable fallbacks; if a strong key is already in the environment, keep using it and prefer not echoing it into logs.

Generate a strong key on any machine if you want one before opening the console:

```bash
openssl rand -hex 32
```

Paste that into the RunPod Secret named `VLLM_API_KEY`.

### Step 2 — inside the Pod (Web Terminal)

```bash
# Optional — scripts auto-prefer /workspace when writable; set only to override:
# export HF_CACHE=/workspace/huggingface HF_HOME=/workspace/huggingface
# export VLLM_CACHE_ROOT=/workspace/vllm-cache
# optional: export EXEC_MODE=native

curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | sh
cd ~/mycmd/qwen3-8-flash-next/rtx-6000-pro
mise install
just config
just check
just setup      # native: no Docker/NCT; downloads weights into HF_CACHE
just deploy     # native: starts `vllm serve` from recipe/profile knobs
```

Expect **`Exec mode: native`**. If detection is wrong, set `EXEC_MODE=native` in the template or shell and re-run `just deploy`.

### Step 3 — what each command does on RunPod

| Command | Behavior |
|---------|----------|
| `just config` | `.env` at mode `0600`; creates `VLLM_API_KEY` if the file has none; optional HF prompt; interactive GPU / serve knobs |
| `just check` | GPU, VRAM, driver, RAM, disk near `HF_CACHE`, `vllm` present — does **not** install Docker/CUDA |
| `just setup` | Native: skip Docker/NCT; download weights; skip image pull |
| `just deploy` | Native: explicit `vllm serve …` (template stays idle) |

### Step 4 — call the API

After `just deploy`, use the Pod **Connect** HTTP URL for port **8000** (not a Serverless endpoint ID). Client shape matches OpenAI; set `api_key` to your `VLLM_API_KEY` (`just token`).

- [OpenAI API compatibility](https://docs.runpod.io/serverless/vllm/openai-compatibility) (client libraries / `/chat/completions` — ignore Serverless `base_url` examples; point at your Pod HTTP proxy)
- [Send requests to vLLM](https://docs.runpod.io/serverless/vllm/vllm-requests) (prompt / messages / sampling — same payload ideas over the Pod URL)
- Extra engine knobs catalog: [vLLM environment variables](https://docs.runpod.io/serverless/vllm/environment-variables) (Serverless worker list — for this recipe prefer `just config` / profiles over `MODEL_NAME`-style template vars)

### Security note (proxy)

A bearer `VLLM_API_KEY` does **not** lock down every vLLM HTTP path (docs: `/v1`, `/v2`, `/inference` are covered; others such as `/invocations` may not be). Treat RunPod’s HTTPS proxy and network controls as part of the perimeter.

Rough public listing (verify in console): ~96 GB VRAM + ~188 GB system RAM + 16 vCPU per RTX PRO 6000. Those scale with GPU count; **container disk does not**. Trust `just check`.

Need Jupyter? Use RunPod’s PyTorch template as a **separate** workflow — not this inference recipe.

---

## Serve defaults (push limits)

Dial down in `just config` or via env if you need headroom.

| Knob | Default |
|------|---------|
| `--max-model-len` | `auto` |
| `--max-num-batched-tokens` | `8192` |
| `--max-num-seqs` | `256` |
| `--gpu-memory-utilization` | `0.95` |
| `--tensor-parallel-size` | = GPU count |
| extras | prefix-caching, `moe-backend marlin`, no flashinfer autotune, tool parsers |

| GPUs | Status | PLE |
|------|--------|-----|
| 1 | validated-intent | host RAM offload |
| 4 | validated | GPU-resident |
| 2, 3, 5, 6, 7, 8 | experimental | confirm prompt |

- Interactive TTY: confirm GPU count and knobs.
- Non-interactive: `RTX_INTERACTIVE=0 PROFILE_CONFIRM=1`.
