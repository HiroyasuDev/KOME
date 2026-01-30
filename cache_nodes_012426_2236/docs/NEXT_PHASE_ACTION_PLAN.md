# Next-Phase Action Plan — Streaming + GPU Arbitration

**Purpose**: Close the two architectural gaps so the system is “performance-correct,” not just “documentation-complete.” References [STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md) and [GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md).

---

## Where You’re At (Accurate)

- **CORE GPU (.30)** documented: vLLM (:8000), Ollama (:11434), TensorFlow Serving (:8500 gRPC / :8501 REST).
- **OKOME (.25)** documented as gateway that chooses which backend to call.
- **EDGE nodes (.41–.50)** documented by role class (Ingress, Cache/Stream, Speculative GPU, Observability).

That’s the **static architecture**. What was missing is **runtime behavior** that makes it feel like ChatGPT. The two new docs close that.

---

## Gap #1 — Streaming Data-Plane (Closed by STREAMING_DATA_PLANE.md)

**Problem**: If OKOME (.25) is inline for *every streamed token*, it becomes jitter injector, scaling ceiling, and single point of failure.

**Target**: OKOME (.25) = **control plane** only. **NODE-03–06** = **stream plane** (own SSE/WS, hold connection, buffer tokens, backpressure).

**Doc**: [STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md) — who owns SSE/WS, buffering, retry, backpressure, runtime contract per node.

---

## Gap #2 — GPU Resource Arbitration (Closed by GPU_RESOURCE_ARBITRATION.md)

**Problem**: TF + vLLM + Ollama on .30 without limits → OOMs, random slowdowns, CUDA allocation failures.

**Target**: Choose **Mode A (shared GPU with discipline)** or **Mode B (partitioned)**; enforce memory limits, health checks, load-shedding.

**Doc**: [GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md) — TF vs vLLM vs Ollama arbitration, limits, failure modes, load-shed rules.

---

## Brutal Risk List (What Breaks If You Don’t Fix It)

| Risk | If not fixed |
|------|----------------------|
| .25 inline for tokens | You won’t rival ChatGPT UX (bursty tokens, stalls, worse TTFT/concurrency) |
| TF + vLLM share GPU without limits | Random OOMs and failures |
| No TTFT/jitter metrics | You can’t optimize |
| Edge stream nodes don’t own connection | Edge nodes won’t matter (central bottleneck with extra boxes) |

---

## Next Steps That Actually Matter (Phases)

### Phase 1 — Make streaming correct (highest ROI)

1. **Decide and document**: Who terminates SSE/WS? → **NODE-03–06** ([STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md)).
2. **Update architecture** with corrected data plane: Browser → 01/02 → 03–06 → 30; 03–06 ↔ 25 for control only.
3. **Implement** stream broker on NODE-03–06 (hold SSE/WS, pull from .30, buffer/backpressure).

### Phase 2 — Make TF coexistence stable on .30

1. **Decide** Mode A vs Mode B ([GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md)).
2. **Implement** GPU memory discipline (mandatory if shared): TF memory growth + cap; vLLM `--gpu-memory-utilization`; Ollama env.
3. **Add** health endpoints and load-shed: if TF busy → route to vLLM/Ollama or 503; same for vLLM/Ollama.

### Phase 3 — Make “robust” measurable

Add SLOs and dashboards (NODE-09/10):

- TTFT p50/p95
- Jitter (token interval variance)
- Stream disconnect rate
- Queue depths (edge and core)
- Cache hit rate (hot prefixes/embeddings)

---

## Repo Additions (Done)

1. **[STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md)** — SSE/WS ownership, buffering, retry, backpressure; final flow diagram; runtime contract per node.
2. **[GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md)** — TF vs vLLM vs Ollama arbitration; Mode A/B; limits; failure modes; load-shedding rules.

Architecture docs ([DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md), [STREAMING_ARCHITECTURE.md](../STREAMING_ARCHITECTURE.md), [INFRASTRUCTURE_REFERENCE.md](INFRASTRUCTURE_REFERENCE.md)) and [README.md](../README.md) now reference these two so the rest of the repo stays aligned.

---

*Last updated: 2026-01-30*
