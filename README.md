# KOME

**Documentation index**: [docs/00_index/README.md](docs/00_index/README.md) — index and [MANIFEST](docs/00_index/MANIFEST.md) for all docs. 🚀

**OKOME Frontend Cache Node — Lightweight Edge Cache for Static Assets**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/status-active-success.svg)](https://github.com/HiroyasuDev/KOME)

KOME is a lightweight, disposable edge cache node designed to accelerate OKOME's **frontend static assets** (JavaScript, CSS, images), protect the OptiPlex from direct browser traffic, and reduce latency — without adding operational complexity.

## ✨ Features

- **⚡ Fast**: Sub-10ms cached asset delivery
- **🔄 Disposable**: < 15 minute rebuild time
- **🛡️ Safe**: Passive failover (browser → OptiPlex if cache dies)
- **💾 SD-Friendly**: Minimal writes, log rotation, tmpfs cache option
- **📦 Lightweight**: NGINX only, no Redis/Kubernetes/TLS
- **🎯 Simple**: Boring and disposable by design

## 🏗️ Architecture

```
Browser → KOME Cache Node (192.168.86.20) → OKOME Core (192.168.86.25:3000)
                ↓
         Frontend Assets Cached
         (JS, CSS, images - 24h TTL, 1GB limit)
         API requests pass through uncached
```

### Cache Behavior

**Frontend Cache Only (24h TTL)**:
- `/assets/*` — JavaScript, CSS, images
- `/ui-schema/*` — UI configuration
- `/version/*` — Version info

**Never Cached** (all pass through to OKOME core):
- `/v1/*` — All API endpoints
- `/infer` — Inference requests
- `/stream` — Streaming responses
- WebSockets / SSE
- Authentication endpoints
- POST/PUT/DELETE requests

> **Note**: KOME focuses on frontend asset caching. Backend API caching is available but not recommended for CN00. See `docs/guides/backend-caching.md` for advanced use cases.

## 📋 Requirements

- **Hardware**: Raspberry Pi 3 or newer
- **Storage**: 16GB+ microSD (32GB recommended)
- **OS**: Raspberry Pi OS Lite (64-bit if supported)
- **Network**: Static IP (192.168.86.20)

## 🚀 Quick Start

### Automated Deployment

```bash
# Clone repository
git clone https://github.com/HiroyasuDev/KOME.git
cd KOME

# Verify connectivity
./scripts/verify-connectivity.sh

# Deploy
./scripts/deploy.sh
```

### Manual Deployment

```bash
# On Raspberry Pi
sudo ./scripts/bootstrap.sh
```

### Two-Node OKOME (Complete)

Frontend (CN00) + Backend (CN01) are configured and validated. One-command check:

```bash
./cache_nodes_012426_2236/scripts/okome-validate.sh
```

**Access**: CN00 `usshopper` @ 192.168.86.20 · CN01 `ussfitzgerald` @ 192.168.86.19  
**Details**: [cache_nodes_012426_2236/READY.md](cache_nodes_012426_2236/READY.md)

## 📊 Performance

- **Cache Hit Ratio**: Target > 80% for static assets
- **Cached Requests**: < 10ms latency
- **Uncached Requests**: ~50-100ms latency (upstream)
- **Resource Usage**: < 5% CPU, ~50-100 MB RAM

## 🛠️ Operations

### Test Cache Node

```bash
./scripts/test.sh
```

### View Statistics

```bash
./scripts/stats.sh
```

### Purge Cache

```bash
./scripts/purge.sh
```

### Monitor Logs

```bash
sshpass -p "usshopper" ssh -p 22 ncadmin@192.168.86.20 \
  "sudo tail -f /var/log/nginx/access.log"
```

## 📚 Documentation

- **Setup Guide**: `docs/setup/installation.md`
- **Operations Runbook**: `docs/operations/runbook.md`
- **Client Configuration**: `docs/guides/client-config.md`
- **Backend Caching**: `docs/guides/backend-caching.md` (optional)
- **Troubleshooting**: `docs/guides/troubleshooting.md`

## 🔧 Configuration

### Network

| Node | IP | Role |
|------|-----|------|
| Router | 192.168.86.1 | Gateway |
| OKOME Core | 192.168.86.25 | Upstream |
| KOME Cache | 192.168.86.20 | Cache Node |

### Cache Settings

- **Cache Size**: 1 GB (hard cap)
- **Cache TTL**: 24 hours
- **tmpfs Cache**: 256MB (optional, zero SD wear)
- **Log Retention**: 7 days

## 🚫 What's NOT Included

❌ Redis / Memcached  
❌ Kubernetes  
❌ TLS certificates  
❌ Active health checks  
❌ Lua / JavaScript in NGINX  
❌ Cloudflare on this node  
❌ Model storage  
❌ Secrets / credentials  

**This node stays boring and disposable.**

## 📖 Related Projects

- **OKOME**: Main LLM stack — https://github.com/HiroyasuDev/OKOME

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

## 🤝 Contributing

This is a focused, minimal cache node. Contributions should maintain simplicity and disposability.

---

**Status**: ✅ Production Ready  
**Last Updated**: 2026-01-22
