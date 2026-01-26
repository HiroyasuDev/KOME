# KOME Architecture

## Overview

KOME is a lightweight, disposable edge cache node designed to accelerate OKOME's **frontend static assets only**. It sits between browsers and the OKOME core, caching JavaScript, CSS, and images to reduce latency and protect the OptiPlex from direct browser traffic. All API requests pass through uncached.

## Architecture Diagram

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ HTTP (port 80)
       │
┌──────▼──────────────────┐
│   KOME Cache Node       │
│   (192.168.86.20)       │
│                         │
│   ┌─────────────────┐   │
│   │  NGINX          │   │
│   │  - Cache        │   │
│   │  - Compression  │   │
│   │  - Rate Limit   │   │
│   └─────────────────┘   │
└──────┬──────────────────┘
       │
       │ Proxy (HTTP)
       │
┌──────▼──────────────────┐
│   OKOME Core            │
│   (192.168.86.25:3000)  │
│   - Open WebUI          │
└─────────────────────────┘
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

### Non-Cached Paths (All Pass Through)

All other requests pass through to OKOME core without caching:
- `/v1/*` — All API endpoints
- `/infer` — Inference requests
- `/stream` — Streaming responses
- WebSockets / SSE
- Authentication endpoints (`/v1/auth`)
- POST/PUT/DELETE requests

> **Note**: CN00 focuses exclusively on frontend asset caching. Backend API caching is available as an advanced option (see `docs/guides/backend-caching.md`) but is not recommended for the primary cache node.

## Failure Model

### Cache Node Failure

- **Impact**: Browser can't connect to cache node
- **Recovery**: Point browser directly to OptiPlex (192.168.86.25:3000)
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
