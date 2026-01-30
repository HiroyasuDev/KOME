# Streaming Data-Plane — Who Owns the SSE/WS Connection

**Scope**: Defines who terminates and holds the streaming connection (SSE/WebSocket), who does control vs token relay, and the runtime contract so the system feels like ChatGPT instead of a central bottleneck.

**Status**: Target architecture. Implement when moving from “path through OKOME .25 for all traffic” to “control plane (.25) + stream plane (03–06).”

---

## The Gap (Why This Doc Exists)

If **OKOME (.25)** is inline for *every streamed token*, it becomes:

- **Jitter injector** — bursty token delivery
- **Scaling ceiling** — one process handling all streams
- **Single point of failure** — stalls during tool calls, worse TTFT, worse concurrency

**Correct target**: OKOME (.25) is **control plane** only. **NODE-03–06** own the **stream plane** (SSE/WS connection to the client and token delivery).

---

## Control Plane vs Stream Plane

| Plane | Owner | Owns | Does NOT own |
|-------|--------|------|------------------|
| **Control** | OKOME 192.168.86.25 | Auth/session, routing policy, tool orchestration, model selection, metadata persistence | Per-token relay |
| **Stream** | NODE-03–06 (192.168.86.43–46) | SSE/WS connection to client, token buffering (anti-jitter), retry/resume, hot-cache (prefixes, tool schemas, embeddings), backpressure | Final truth, tool execution, long-term storage |

**CORE GPU (.30)** remains the single source of truth for model output. NODE-03–06 receive authoritative tokens from .30 and stream them to the client; they do not generate or alter content.

---

## Final Streaming Data-Plane (Target)

```
Browser
  ↓  SSE / WebSocket (single long-lived connection)
NODE-01 or NODE-02 (Ingress) — TLS + stickiness, connection upgrade
  ↓  sticky session → same stream node
NODE-03, 04, 05, or 06 (Edge Stream) — holds SSE/WS, buffers tokens, backpressure
  ↓  authoritative tokens
  ↘  CORE GPU 192.168.86.30 (vLLM / Ollama / TensorFlow)
  ↕  control only (auth, model choice, tool policy)
OKOME 192.168.86.25 — not in token path
```

- **Token path**: Browser ↔ NODE-01/02 ↔ NODE-03–06 ↔ CORE GPU (.30). OKOME (.25) is **not** in this path.
- **Control path**: NODE-03–06 ↔ OKOME (.25) for auth, session, routing policy, model selection, tool orchestration. .25 does not see every token.

---

## Who Terminates SSE/WS (Ownership)

| Component | Terminates SSE/WS? | Role |
|-----------|--------------------|------|
| **NODE-03–06** | **Yes** (target) | Hold the connection to the client; receive tokens from .30; stream to client with buffering/backpressure |
| NODE-01/02 | No (pass-through or upgrade only) | Route to 03–06; stickiness so same client → same 03–06 |
| OKOME .25 | No (target) | Control only; no per-token relay |
| CORE GPU .30 | No | Produces tokens; sends to 03–06 (or to .25 only in current “path through .25” mode) |

**Implementation note**: A “stream broker” service on NODE-03–06 should:

- Accept SSE/WS from the client (or from 01/02 after upgrade).
- Request authoritative stream from CORE GPU (.30) (or via a control call to .25 that returns “connect to .30 for this session”).
- Receive tokens from .30; optionally buffer for anti-jitter; stream to client.
- Apply backpressure so the UI never stalls (slow client → pause or buffer; never block .30 indefinitely).
- Emit minimal telemetry (e.g. to NODE-09/10).

---

## Buffering, Retry, Backpressure

| Concern | Owner | Contract |
|---------|--------|----------|
| **Anti-jitter buffering** | NODE-03–06 | Small buffer (e.g. 1–2 tokens or 50–100 ms) so token delivery to client is smooth; do not accumulate full response. |
| **Retry / resume** | NODE-03–06 | On disconnect or .30 timeout, support resume (e.g. cursor/offset) so client can reconnect without full re-inference; coordinate with .25 for session. |
| **Backpressure** | NODE-03–06 | If client is slow, backpressure to .30 (e.g. pause pull or signal) so .30 doesn’t run unbounded; UI never “stalls” due to proxy blocking. |
| **Hot-cache** | NODE-03–06 | Prefixes, tool schemas, recent embeddings (e.g. Redis on 03–06 or shared .19); never cache “final truth” or long-term state. |

---

## NODE-01/02 (Ingress) — Runtime Contract

**Owns:**

- TLS termination (optional internal)
- Connection upgrade to WS/SSE
- Sticky routing (session → same NODE-03–06)
- Rate limiting

**Does NOT own:**

- Caching
- Streaming buffers
- Inference

**Robustness:**

- Active health checks to NODE-03–06, .25, and .30
- Fast failover (no state other than routing tables)

---

## NODE-03–06 (Edge Stream) — Runtime Contract

**Owns:**

- The actual SSE/WS connection to the client
- Buffering tokens (anti-jitter)
- Retry/resume (e.g. cursor)
- Hot-cache (prefixes, tool schemas, recent embeddings)
- Backpressure so UI never stalls

**Does NOT own:**

- Final truth (that’s CORE GPU .30)
- Tool execution (unless strictly sandboxed)
- Long-term storage

---

## NODE-07/08 (Speculative GPU) — Optional

Only worth it if measured (TTFT improvement).

**Owns:** Draft tokens; speculative decode with rollback policy.  
**Does NOT own:** Final answers; tool calls; truth.

If no GPUs on 07/08: repurpose as extra 03–06 capacity (often higher ROI).

---

## NODE-09/10 (Observability)

**Owns:** Prometheus, Grafana, Loki; SLO dashboards (TTFT, jitter, errors, queue depth); alerting.  
**Does NOT own:** Production traffic path; inference; caches.

---

## Phase 1 Actions (Streaming Correct)

1. **Decide and document**: Who terminates SSE/WS? → **NODE-03–06** (this doc).
2. **Update architecture** with corrected data plane:
   - Token path: Browser → 01/02 → 03–06 → 30.
   - Control: 03–06 ↔ 25 (auth, policy, model choice).
3. **Implement** stream broker on 03–06 (or proxy that holds connection and pulls from .30 with buffering/backpressure).

---

## Related Docs

- [DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md) — Node roles and base config
- [STREAMING_ARCHITECTURE.md](../STREAMING_ARCHITECTURE.md) — Current path-through-.25 and Nginx rules (interim)
- [GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md) — TF vs vLLM vs Ollama on .30

---

*Last updated: 2026-01-30*
