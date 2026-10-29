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
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | bash
cd ~/mycmd/qwen3-8-flash-next/rtx-6000-pro   # path may vary after extract
# Bootstrap installs mise when missing; otherwise:
#   bash scripts/ensure_mise.sh && mise install
just config
just doctor
just setup
just deploy
just probe
```

Lifecycle after that: `just status` · `just logs` · `just benchmark` · `just gpu` · `just snapshot` · `just stop` · `just token`.

**HF token:** prefer a RunPod Secret / injected `HF_TOKEN` (also accepts `HUGGING_FACE_HUB_TOKEN`). Blank `HF_TOKEN=` in `.env` does **not** clobber a Secret. `just config` / doctor report **present/absent** only — never the value. Provider-injected tokens are not copied into `.env`.

**Image:** use `vllm/vllm-openai:qwen38-flash-next` (or a pinned digest). `just doctor` **fails** on `:latest`.

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

**Idea:** [RunPod](https://runpod.io?ref=k2vwrktx) gives you the GPU and the official vLLM image. This tarball owns config → check → setup → deploy. The Pod should start in an **idle shell**, not already serving a model.

### Step 1 — create or edit the template

1. Sign up / open the console via [RunPod](https://runpod.io?ref=k2vwrktx) → **Pods** → create a Pod (or open a saved template).
2. Search and select image **`vllm/vllm-openai:qwen38-flash-next`**.  
   Avoid PyTorch 2.2 Jupyter and `vllm/vllm-openai:latest`.
3. Click the **Edit** control (**pencil**). Selecting the image alone is not enough — you must edit the fields below.

| Field | Value |
|-------|--------|
| Name | e.g. `qwen3-8-flash-next-rtx-6000-pro` |
| Container image | `vllm/vllm-openai:qwen38-flash-next` (pin a digest when you have one; see `recipe.yaml`) |
| CUDA host | ≥ 13.0 |
| GPU | RTX PRO 6000 × **1–8**, same node |
| Container disk | **≥ 175–200 GB** if staging weights locally; else **50–80 GB** OS-only |
| Volume disk | Prefer **Network Volume (HP if available) ≥ 250 GB** as **hot** HF/vLLM cache. Optional **Global Volume** as cold archive only. |
| Volume mount path | Hot: **`/workspace`**. Cold archive (optional): **`/workspace-global`**. Do **not** point vLLM load at Global/geesefs by default. |
| Expose HTTP | **8000** (RunPod HTTPS proxy) |
| Expose TCP | **22** (required for [SSH](https://docs.runpod.io/pods/configuration/use-ssh) / [VS Code or Cursor](https://docs.runpod.io/pods/configuration/connect-to-ide) / agent e2e) |
| **Env vars** | Knobs + Secret interpolation — see copy-paste block below |
| **Secrets** | `HF_TOKEN` and preferably `VLLM_API_KEY` — [Manage secrets](https://docs.runpod.io/pods/templates/secrets) |

#### Container start command (required)

The image entrypoint is `vllm serve`. If you only put `sleep infinity` in Start CMD, RunPod passes that as **arguments to `vllm serve`**, not as a shell command.

Paste this JSON into **Container start command** (overrides entrypoint + cmd). It keeps an **idle** shell (recipe owns `vllm serve`) **and** installs/starts OpenSSH so TCP **22** / agent SSH work on this custom image:

```json
{"entrypoint":["/bin/bash"],"cmd":["-lc","apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server >/dev/null && mkdir -p ~/.ssh && chmod 700 ~/.ssh && if [ -n \"${PUBLIC_KEY:-}\" ]; then echo \"$PUBLIC_KEY\" >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; fi; service ssh start; sleep infinity"]}
```

You should get a Pod with CUDA / PyTorch / vLLM installed and **no model running**. Connect with [SSH](https://docs.runpod.io/pods/configuration/use-ssh) / [VS Code or Cursor](https://docs.runpod.io/pods/configuration/connect-to-ide) (TCP **22**), or use Web Terminal.

**Storage (RunPod):** split **archive** vs **load**.

| Tier | Mount | Role |
|------|-------|------|
| Hot (preferred) | `/workspace` Network Volume (HP > standard) | HF cache **vLLM loads from**; TorchInductor / Triton / temp |
| Cold archive | `/workspace-global` Global Volume | Persistent copy only — **do not mmap-serve** via geesefs |
| Local stage | large container/NVMe disk | Optional: sequential Global → local copy, then load |

Prefer: local NVMe > HP network vol > standard network vol > Global+eager/prefetch > Global+lazy mmap (**fail profile**).

Cold-start gate: **~1 h weight load = failed deploy** even if `/v1/models` later returns 200.

#### Env vars — copy into the template editor

Paste into RunPod’s environment / raw editor. Secret values come from [Manage secrets](https://docs.runpod.io/pods/templates/secrets) via `{{ RUNPOD_SECRET_… }}` interpolation (not plaintext tokens):

```bash
EXEC_MODE=native
VLLM_API_KEY="{{ RUNPOD_SECRET_VLLM_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN }}"

# Hot path — Network Volume / local (NOT Global geesefs for load)
RTX_VOLUME_ROOT=/workspace
HF_CACHE=/workspace/huggingface
HF_HOME=/workspace/huggingface
VLLM_CACHE_ROOT=/workspace/vllm-cache

# Cold archive only (optional). Do not set HF_* here for serve:
# RTX_ARCHIVE_ROOT=/workspace-global

# Loader (network/object FS — test A then B; keep threads modest on FUSE)
# SAFETENSORS_LOAD_STRATEGY=eager
# SAFETENSORS_LOAD_STRATEGY=prefetch
# VLLM_SAFETENSORS_LOAD_THREADS=4

# READY_TIMEOUT_SEC=1800
# RTX_INTERACTIVE=0
# PROFILE_CONFIRM=1
```

| Variable | Required? | What it does |
|----------|-----------|--------------|
| `EXEC_MODE` | No | Force `native` or `docker`. Unset → auto-detect. |
| `RTX_VOLUME_ROOT` | No | **Hot** cache root (prefer `/workspace` NVMe/network). Opt-in; not auto-picked from Global. |
| `RTX_ARCHIVE_ROOT` | No | Cold Global archive (future stage path). Not the load path. |
| `HF_CACHE` / `HF_HOME` | Recommended | Where vLLM **reads** weights. Keep on hot FS. |
| `VLLM_CACHE_ROOT` | Recommended | Compile cache — prefer hot FS, not Global. |
| `SAFETENSORS_LOAD_STRATEGY` | No | `eager` (try first) or `prefetch` when FS ≠ local NVMe. |
| `VLLM_SAFETENSORS_LOAD_THREADS` | No | Multithread load; start **4** (not 16–32 on geesefs). |
| `READY_TIMEOUT_SEC` | No | Wait for `/v1/models` (default **1800**). |
| `RTX_INTERACTIVE=0` | No | Skip TTY prompts (+ `PROFILE_CONFIRM=1` for experimental GPU counts). |

> Prefer: explicit `HF_*` / `VLLM_CACHE_ROOT` → else writable `RTX_VOLUME_ROOT` → else `/workspace` → else `/runpod-volume`. Never treat Global as default load root.

#### Secrets (RunPod Secrets UI)

Create and attach secrets per [Manage secrets](https://docs.runpod.io/pods/templates/secrets). Wire them into the env block with:

```bash
VLLM_API_KEY="{{ RUNPOD_SECRET_VLLM_API_KEY }}"
HF_TOKEN="{{ RUNPOD_SECRET_HF_TOKEN }}"
```

(or the key-icon picker). Do **not** paste raw token values into the template.

| Secret | Why |
|--------|-----|
| `HF_TOKEN` | Faster / authenticated Hugging Face downloads for gated or rate-limited models. Strongly recommended even when the card looks public. |
| `VLLM_API_KEY` | Bearer key for the OpenAI-compatible API. Prefer a **cryptographically random** value (~32+ bytes / 64 hex chars). Avoid short passwords and avoid relying on any predictable provider default. |

At Pod start, Secrets are injected as normal environment variables. `just config` still ensures a local `.env` (mode `0600`) for portable fallbacks; if a strong key / `HF_TOKEN` is already in the environment (or as `HUGGING_FACE_HUB_TOKEN`), keep using it and **do not** copy the Secret into `.env`. Blank `HF_TOKEN=` lines never override an injected Secret.

Generate a strong key on any machine if you want one before opening the console:

```bash
openssl rand -hex 32
```

Paste that into the RunPod Secret named `VLLM_API_KEY`.

### Step 2 — inside the Pod (Web Terminal)

```bash
# Hot cache on Network Volume / local — not Global geesefs:
export RTX_VOLUME_ROOT=/workspace
export HF_CACHE=/workspace/huggingface HF_HOME=/workspace/huggingface
export VLLM_CACHE_ROOT=/workspace/vllm-cache
# If only Global is attached: stage to local first, or set SAFETENSORS_LOAD_STRATEGY=eager

curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/rtx-6000-pro@beta" | bash
cd ~/mycmd/qwen3-8-flash-next/rtx-6000-pro
# mise: bash scripts/ensure_mise.sh && mise install
just config
just check
just setup
just deploy
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

## Serve defaults

**1× GPU (conservative first-boot):** `CTX=16384`, `SEQS=2`, `MAX_NUM_BATCHED_TOKENS=4096`, `GPU_MEM=0.90`, prefix-caching **off**, `VLLM_PLE_CPU_OFFLOAD=1` (specialized PLE path — **not** generic `--cpu-offload-gb`).

**4× / push-limit profiles:** `max-model-len=auto`, batched tokens `8192`, `SEQS=256`, `GPU_MEM=0.95`, prefix-caching on. Dial via `just config` or env.

| Knob | 1× bring-up | 4× / push-limit |
|------|-------------|-----------------|
| `--max-model-len` | `16384` | `auto` |
| `--max-num-batched-tokens` | `4096` | `8192` |
| `--max-num-seqs` | `2` | `256` |
| `--gpu-memory-utilization` | `0.90` | `0.95` |
| `--tensor-parallel-size` | = GPU count | = GPU count |
| prefix-caching | off | on |
| PLE | `VLLM_PLE_CPU_OFFLOAD=1` (host RAM intent) | GPU-resident |

| GPUs | Status | PLE |
|------|--------|-----|
| 1 | validated-intent | conservative bring-up + `VLLM_PLE_CPU_OFFLOAD=1` on `qwen38-flash-next`; refuse `:latest` (BF16 ~95 GiB OOM). Scale CTX/SEQS after probe green |
| 4 | validated | GPU-resident |
| 2, 3, 5, 6, 7, 8 | experimental | confirm prompt |

- Interactive TTY: confirm GPU count and knobs.
- Non-interactive: `RTX_INTERACTIVE=0 PROFILE_CONFIRM=1`.
- `RTX_VOLUME_ROOT` = **hot** load root (`/workspace`). Global = archive only.
- FUSE/geesefs: doctor warns on 0-byte snapshot stubs; direct load = failed cold-start profile.
