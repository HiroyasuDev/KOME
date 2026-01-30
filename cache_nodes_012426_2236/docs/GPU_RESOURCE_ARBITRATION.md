# GPU Resource Arbitration — TensorFlow vs vLLM vs Ollama on 192.168.86.30

**Scope**: Defines how TensorFlow Serving, vLLM, and Ollama coexist on CORE GPU (192.168.86.30): shared vs partitioned GPU, memory limits, health endpoints, load-shedding, and failure modes.

**Status**: Mandatory before running all three on .30; prevents OOMs and random slowdowns.

---

## The Gap (Why This Doc Exists)

Ports are documented (TF 8500/8501, vLLM 8000, Ollama 11434). What’s missing is the **runtime contract**:

- If TF + vLLM + Ollama share one GPU without limits → OOMs, CUDA allocation failures, hard-to-debug slowdowns.
- You must choose **Mode A (shared GPU with discipline)** or **Mode B (partitioned / dedicated)** and enforce it.

---

## Two Correct Modes (Pick One)

### Mode A — Shared GPU (fastest to ship, needs discipline)

All services run on the **same GPU**. You **must** enforce limits.

| Service | What to set | Purpose |
|---------|-------------|---------|
| **TensorFlow** | GPU memory growth; cap per-process memory | Avoid TF claiming all VRAM |
| **vLLM** | `--gpu-memory-utilization` (e.g. 0.5–0.6 when shared) | Leave headroom for TF and Ollama |
| **Ollama** | `OLLAMA_GPU_OVERHEAD`, limit concurrent models | Avoid runaway allocations |

**Rules:**

- Do **not** run all three at max greed simultaneously.
- Set TF: `tf.config.experimental.set_memory_growth(True)` and/or `set_per_process_memory_fraction`.
- Set vLLM: e.g. `--gpu-memory-utilization 0.55` so ~45% VRAM remains for TF/Ollama.
- Set Ollama: `OLLAMA_GPU_OVERHEAD=1024`; keep one model loaded if possible; avoid loading multiple large models at once.

**Failure mode if ignored**: OOM, random slowdowns, CUDA “out of memory” or “resource exhausted.”

---

### Mode B — Dedicated GPU partitioning (cleaner long-term)

If you have **multiple GPUs** or **MIG** (Multi-Instance GPU):

| GPU / partition | Service |
|-----------------|---------|
| GPU 0 (or MIG slice 0) | TensorFlow Serving |
| GPU 1 (or MIG slice 1) | vLLM |
| (optional) GPU 2 or CPU | Ollama fallback or small model |

Use `CUDA_VISIBLE_DEVICES` per process:

- TF Serving: `CUDA_VISIBLE_DEVICES=0`
- vLLM: `CUDA_VISIBLE_DEVICES=1`
- Ollama: `CUDA_VISIBLE_DEVICES=1` (share with vLLM) or `0` (share with TF) if only two GPUs.

**Production approach** when hardware allows; avoids contention and OOM from sharing.

---

## Arbitration and Load-Shedding Rules

| Condition | Action |
|-----------|--------|
| **TF busy / overloaded** | Route TF requests to queue or return 503; OKOME or edge routes to vLLM/Ollama if applicable, or “degrade gracefully” (e.g. “TF unavailable, use LLM only”). |
| **vLLM OOM or unhealthy** | Health check fails → stop sending new vLLM requests; retry later; optionally fail over to Ollama if same model exists. |
| **Ollama cold / slow** | Use `OLLAMA_KEEP_ALIVE` to keep model warm; if Ollama unhealthy, route to vLLM or return 503. |
| **All backends busy** | Return 503 Retry-After or queue; do not start new inference that would OOM. |

**Health endpoints** (must exist and be used):

- TF Serving: `GET http://192.168.86.30:8501/v1/models` (or `/v1/models/${model}/status`).
- vLLM: `GET http://192.168.86.30:8000/health` (or equivalent).
- Ollama: `GET http://192.168.86.30:11434/api/version` or `/api/tags`.

OKOME (.25) or the edge stream nodes (03–06) should check these before routing and apply load-shedding when a backend is unhealthy or overloaded.

---

## Failure Modes and Mitigations

| Failure | Mitigation |
|---------|------------|
| **TF OOM** | Cap TF memory (Mode A); reduce batch size or model size; or move TF to dedicated GPU (Mode B). |
| **vLLM OOM** | Lower `--gpu-memory-utilization`; reduce `--max-model-len` or batch size; ensure TF/Ollama not starving vLLM. |
| **Ollama OOM** | One model at a time; `OLLAMA_GPU_OVERHEAD`; or run Ollama on CPU for small models. |
| **CUDA allocation failure** | One of the above; check `nvidia-smi` and per-process limits; enforce Mode A limits or switch to Mode B. |
| **TF slow / stuck** | Timeout on .25 or edge; route to vLLM/Ollama or return 503; restart TF Serving if needed. |
| **All backends unhealthy** | Return 503; alert (NODE-09/10); do not relay tokens until at least one backend is healthy. |

---

## Recommended Repo / Config Additions

1. **Document chosen mode** (A or B) in this file or in `docs/GPU_HOST_TENSORFLOW_INTEGRATION.md`.
2. **Startup or systemd** on .30:
   - Mode A: set TF memory growth and cap; vLLM `--gpu-memory-utilization 0.55` (or similar); Ollama env as above.
   - Mode B: set `CUDA_VISIBLE_DEVICES` per service.
3. **Health checks** in OKOME or edge: poll 8501, 8000, 11434; load-shed or failover when unhealthy.
4. **SLO / dashboards** (NODE-09/10): track TF/vLLM/Ollama latency and error rate; alert on OOM or health failure.

---

## Summary Table

| Topic | Mode A (shared) | Mode B (partitioned) |
|-------|------------------|----------------------|
| **GPU** | One GPU shared | Multiple GPUs or MIG |
| **TF** | Memory growth + cap; limit batch | `CUDA_VISIBLE_DEVICES=0` |
| **vLLM** | `--gpu-memory-utilization 0.55` (or lower) | `CUDA_VISIBLE_DEVICES=1` |
| **Ollama** | `OLLAMA_GPU_OVERHEAD`; one model warm | Dedicated GPU or share with vLLM |
| **Load-shed** | Mandatory: health checks + 503 when overloaded | Same |
| **Failure** | OOM if limits ignored | Cleaner; fewer OOMs if partitioned correctly |

---

## Related Docs

- [GPU_HOST_TENSORFLOW_INTEGRATION.md](GPU_HOST_TENSORFLOW_INTEGRATION.md) — TF on .30 and OKOME .25 integration
- [STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md) — Who owns SSE/WS; stream vs control plane
- [DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md) — Node roles

---

*Last updated: 2026-01-30*
