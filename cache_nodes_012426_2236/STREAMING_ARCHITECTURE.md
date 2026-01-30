# KOME Streaming Architecture — Path Through OKOME (192.168.86.25)

**Scope**: All traffic goes through OKOME at 192.168.86.25. KOME frontend (192.168.86.20) optimizes for full throughput and all failure modes.

**Target (next phase)**: Move token streaming to the **stream plane** (NODE-03–06 own SSE/WS); OKOME (.25) becomes **control plane** only (auth, policy, model choice). See [docs/STREAMING_DATA_PLANE.md](docs/STREAMING_DATA_PLANE.md).

---

## Strict IP Focus

| IP | Role | Purpose |
|----|------|---------|
| **192.168.86.25** | OKOME Web UI / Gateway | **Single path** for all traffic; OKOME talks to GPU (.30) and Redis (.19) internally |
| **192.168.86.20** | Frontend (Nginx) | Pass-through to .25 only; no buffering for API/streaming; cache static/UI; failure handling |
| **192.168.86.30** | GPU (vLLM / Ollama) | Used by OKOME on .25 for inference — not proxied directly by KOME |
| **192.168.86.19** | Backend Cache (Redis) | Used by OKOME on .25 — planner, RAG; never live tokens at edge |

**KOME exists solely to support OKOME at 192.168.86.25** with full throughput and robust failure handling on the path Browser → .20 → .25.

---

## Golden Rule (Path Through OKOME)

> **All traffic goes through OKOME at 192.168.86.25.**  
> KOME frontend (.20) does not buffer API/streaming; long timeouts and retries for inference; static served from cache or stale when .25 is down.

- Edge (.20) = single upstream .25; no direct proxy to .30 from KOME.
- OKOME on .25 handles routing to GPU (.30) and streaming to the browser.
- KOME ensures: no buffering on API/stream paths, 600s read/send timeouts, retries on 502/503/504, stale cache when .25 is unhealthy.

---

## Data Flow (Path Through .25)

### All traffic

```
Browser
  ↓
192.168.86.20 (Nginx) — single upstream 192.168.86.25:8000
  ↓
192.168.86.25 (OKOME) — UI, API, streaming; OKOME calls .30 (GPU) and .19 (Redis) internally
  ↓
Browser
```

- **API / streaming** (`/v1/*`, `/api/*`, `/execute`, `/agent`, `/run`, `/ws`): proxied to .25 with `proxy_buffering off`, `proxy_request_buffering off`, `chunked_transfer_encoding on`, `proxy_read_timeout 600s`, `proxy_send_timeout 600s`, and `proxy_next_upstream error timeout http_502 http_503 http_504` for retries.
- **Static / UI** (`/`, `/assets/*`, `/ui-schema/*`, `/version`, `/health`): proxied to .25 with cache; `proxy_cache_use_stale` on errors; on 502/503/504 without stale → maintenance page (503 + Retry-After).

### Failures

- **OKOME (.25) down**: Health probe sets `$okome_upstream_ok 0`; static locations serve stale cache or `@okome_maintenance` (503); API requests get retries then 502/503 from upstream.
- **Timeouts**: 5s connect, 600s read/send for API; 60s for static.
- **Retries**: `proxy_next_upstream error timeout http_502 http_503 http_504` with `proxy_next_upstream_tries 2`.

---

## Nginx Requirements (Throughput + No Buffering for API)

For **API / streaming** locations (path to .25):

```nginx
proxy_buffering off;
proxy_request_buffering off;
proxy_cache off;
chunked_transfer_encoding on;
proxy_connect_timeout 5s;
proxy_read_timeout 600s;
proxy_send_timeout 600s;
proxy_next_upstream error timeout http_502 http_503 http_504;
proxy_next_upstream_tries 2;
```

For **static** locations: cache + `proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504` and `error_page 502 503 504 = @okome_maintenance`.

---

## Verification

**Health of OKOME (.25):**

```bash
curl -fsS --max-time 3 http://192.168.86.25:8000/health
```

**Via KOME frontend (.20):**

```bash
curl -I http://192.168.86.20/
curl -I http://192.168.86.20/health
```

**Streaming** is between browser and OKOME (.25); OKOME connects to GPU (.30). To verify streaming, use the Web UI or hit OKOME’s API endpoint through .20 (e.g. `/v1/chat/completions` or whatever OKOME exposes). If streaming is slow, check OKOME (.25) and GPU (.30); KOME (.20) is configured for unbuffered pass-through to .25.

---

## Node Role Summary

| Node | Role |
|------|------|
| 192.168.86.20 (Frontend) | Single upstream .25; no buffering for API/stream; cache + stale + maintenance on failure |
| 192.168.86.25 (OKOME) | **Path through** — all traffic; OKOME handles GPU (.30) and Redis (.19) |
| 192.168.86.30 (GPU) | Used by OKOME; not proxied directly by KOME |
| 192.168.86.19 (Redis) | Used by OKOME; not proxied by KOME |

---

*Last updated: 2026-01-30 — path through OKOME .25 only; full throughput and failure handling*
