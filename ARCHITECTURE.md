# KOME Architecture

## Overview

KOME is a lightweight edge cache with **path through OKOME (192.168.86.25) only**:

- **192.168.86.25** — OKOME Web UI / Gateway: **single path** for all traffic; OKOME talks to GPU (.30) and Redis (.19) internally.
- **192.168.86.20** — Frontend (Nginx): all traffic to .25 only; no buffering for API/stream; cache + failure handling.
- **192.168.86.30** — CORE GPU: used by OKOME on .25 for TensorFlow (8500/8501), vLLM (8000), Ollama (11434); not proxied directly by KOME.
- **192.168.86.19** — Backend (Redis): used by OKOME on .25; **never** live tokens at edge.
- **192.168.86.41–50** — EDGE nodes (NODE-01–10): Ingress/Router (.41/.42), Cache/Stream (.43–.46), Speculative GPU (.47/.48), Observability (.49/.50); see `cache_nodes_012426_2236/docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md`.

**Golden rule**: All traffic goes through OKOME at 192.168.86.25. KOME (.20) does not buffer API/stream; long timeouts and retries for inference; static served from cache or stale when .25 is down. See `cache_nodes_012426_2236/STREAMING_ARCHITECTURE.md`. TensorFlow on .30: `cache_nodes_012426_2236/docs/GPU_HOST_TENSORFLOW_INTEGRATION.md`.

## Architecture Diagram

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTP (port 80)
       │
┌──────▼──────────────────┐
│   KOME Frontend         │
│   (192.168.86.20)       │
│   Single upstream .25   │
│   No buffer API/stream  │
│   Cache + failure handling
└──────┬──────────────────┘
       │
       └──► 192.168.86.25:8000 (OKOME) — UI, API, streaming
                    │
                    ├──► 192.168.86.30 (CORE GPU) — TensorFlow (8500/8501), vLLM (8000), Ollama (11434)
                    ├──► 192.168.86.19 (Redis) — cache
                    └──► 192.168.86.41–50 (EDGE) — Ingress, Cache/Stream, Speculative GPU, Observability
```

## Components

### NGINX Reverse Proxy

- **Role**: HTTP reverse proxy with caching
- **Port**: 80 (HTTP)
- **Cache**: 1GB limit, 24h TTL
- **Compression**: gzip enabled
- **Rate Limiting**: 10 req/s per IP

### Cache Storage

- **Primary**: `/var/cache/nginx/static` (1GB limit)
- **Optional**: tmpfs mount (256MB, zero SD wear)
- **Retention**: 24 hours inactive, then purge

### Logging

- **Access Logs**: `/var/log/nginx/access.log`
- **Error Logs**: `/var/log/nginx/error.log`
- **Rotation**: Daily, 7-day retention

## Cache Strategy

### Frontend Cache Only (CN00 Focus)

**Cached Paths**:
- `/assets/*` — JavaScript, CSS, images
- `/ui-schema/*` — UI configuration
- `/version/*` — Version info

**TTL**: 24 hours (static assets rarely change)

**Cache Size**: 1GB limit

### Streaming Path (Pass-Through Only — No Buffering)

- **`/v1/*`** — Proxied **directly to 192.168.86.30** (GPU/vLLM). Nginx must use `proxy_buffering off`, `proxy_request_buffering off`, `chunked_transfer_encoding on`. No cache. No token buffering or aggregation on the edge.
- `/infer`, `/stream`, WebSockets, SSE — pass-through to upstream with same unbuffered settings.
- Authentication (`/v1/auth`) and other API paths — pass-through; no caching of live streams.

> **Critical**: LLM streaming must be end-to-end unbuffered. If any node in the path buffers or aggregates tokens, you get "thought for 8 minutes" + slow token drip. Cache only static assets, embeddings, prompts, and **completed** responses — never live tokens. See `cache_nodes_012426_2236/STREAMING_ARCHITECTURE.md`.

## Failure Model

### Cache Node Failure

- **Impact**: Browser can't connect to cache node
- **Recovery**: Point browser directly to OKOME Web UI (192.168.86.25:8000) or GPU (192.168.86.30:8000) for streaming
- **Rebuild Time**: < 15 minutes

### Upstream Failure

- **Impact**: Cache serves stale assets (24h TTL), API calls fail
- **Recovery**: Fix OKOME core, cache auto-refreshes

### Network Partition

- **Impact**: `502 Bad Gateway` errors
- **Recovery**: Check network, verify router/firewall

## Design Principles

1. **Simplicity**: NGINX only, no additional services
2. **Disposability**: Fast rebuild (< 15 min)
3. **Safety**: Passive failover, no data loss
4. **SD-Friendly**: Minimal writes, log rotation
5. **Performance**: Sub-10ms cached responses

## Resource Usage

- **CPU**: < 5% (idle)
- **RAM**: ~50-100 MB (NGINX)
- **Disk**: < 5 GB total (OS + cache + logs)
- **Network**: Minimal (only cached assets)

## Security

- **No TLS**: LAN-only, no secrets
- **No Authentication**: Transparent proxy
- **Rate Limiting**: 10 req/s per IP
- **Firewall**: Only port 80 open (HTTP)

## Monitoring

- **Access Logs**: Real-time request monitoring
- **Cache Headers**: `X-Cache: HIT/MISS`
- **Statistics**: Hit rate, cache size, file counts
- **No Dashboards**: Simple log-based monitoring

---

**Last Updated**: 2026-01-22
