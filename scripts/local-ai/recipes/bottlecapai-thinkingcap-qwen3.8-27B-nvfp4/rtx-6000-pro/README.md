# bottlecapai-thinkingcap-qwen3.8-27B-nvfp4 / rtx-6000-pro

Dense NVFP4 serve for [bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4](https://huggingface.co/bottlecapai/ThinkingCap-Qwen3.8-27B-NVFP4) on 1× RTX PRO 6000 (Blackwell). Same lifecycle as the Spark target; OpenAI-compatible vLLM on port **8000**.

Day-1 defaults match Spark dense serve: CTX 262144, SEQS 4, MTP 3, `--kv-cache-dtype fp8`, image `ghcr.io/styles01/qwen38-mtp3:latest`. No flash-next PLE mmap path.

```bash
export RECIPE=recipes/bottlecapai-thinkingcap-qwen3.8-27B-nvfp4/rtx-6000-pro
just doctor && just setup && just deploy && just probe
```

`HF_TOKEN` required (gated). Multi-GPU DP documented in the Spark README — not wired in this 1× tree.
