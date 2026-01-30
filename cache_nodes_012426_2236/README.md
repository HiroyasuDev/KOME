# OKOME Two-Node Cache Architecture

**Date Created**: 2026-01-24  
**Status**: Implementation Plan  
**Location**: `cache_nodes_012426_2236/`

---

## Overview

This directory contains the complete implementation plan and configurations for transforming KOME from a single frontend cache node to a production-grade two-node cache architecture:

- **Frontend/Edge Cache** (192.168.86.20): Nginx reverse proxy with advanced caching, health-gated failover, and observability
- **Backend/Model Cache** (192.168.86.19): Redis cache for planner outputs, RAG chunks, and model metadata

## Architecture (Path Through OKOME 192.168.86.25)

All traffic goes through OKOME at **192.168.86.25**. KOME frontend (.20) optimizes for full throughput and all failure modes.

| IP | Role |
|----|------|
| **192.168.86.25** | OKOME Web UI / Gateway — **single path** for all traffic; OKOME talks to .30 (GPU) and .19 (Redis) internally |
| **192.168.86.20** | Frontend (Nginx) — all traffic to .25 only; no buffering for API/stream; cache + failure handling |
| **192.168.86.30** | GPU — used by OKOME on .25; not proxied directly by KOME |
| **192.168.86.19** | Backend (Redis) — used by OKOME on .25 |

**Golden rule**: Path through OKOME .25 only. No buffering for API/stream; long timeouts and retries; static from cache or stale when .25 is down. See [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md).

```
Browser
   ↓
192.168.86.18 (VIP) or 192.168.86.20 (Frontend)
   ↓
192.168.86.25:8000 (OKOME) — UI, API, streaming
   ├──► 192.168.86.30 (GPU)
   └──► 192.168.86.19 (Redis)
```

## Implementation Phases

### [Phase 0: Foundation & SD Hardening](00_FOUNDATION.md)
- Raspberry Pi OS Lite setup
- SD wear reduction (fstab, journald, tmpfs)
- Golden image creation procedure
- System hardening (raspi-config, kernel tweaks)

### [Phase 1: Two-Node Basic Setup](01_BASIC_SETUP.md)
- Frontend cache node deployment (Nginx)
- Backend cache node deployment (Redis)
- Basic configuration and verification

### [Phase 2: Health-Gated Failover & Observability](02_FAILOVER_OBSERVABILITY.md)
- Active health probes (systemd timer)
- Stale cache serving on upstream failure
- Comprehensive observability headers
- Cache hit ratio monitoring

### [Phase 3: Cache-Aware Planner & Rate Limiting](03_CACHE_PLANNER.md)
- Redis integration with OKOME planner
- Cache key schema and TTL management
- Budget enforcement (rate limits, write limits)
- Enhanced Nginx rate limiting

### [Phase 4: Advanced Features](04_ADVANCED_FEATURES.md)
- Canary cache policies (header/cookie-based)
- Predictive pre-warming from access patterns
- Per-agent cache budget enforcement
- Cache key versioning

### [Phase 5: Enterprise Hardening](05_ENTERPRISE_HARDENING.md)
- VIP failover with keepalived (192.168.86.18)
- Prometheus node exporter
- SSH hardening (key-only)
- Fail2ban protection
- Chaos testing framework

### [Phase 6: SRE Runbook & Documentation](06_SRE_RUNBOOK.md)
- Incident response procedures (7 incident types)
- Operational golden rules
- Validation scripts
- Storage specifications

### [Streaming Architecture (Strict IP & Golden Rule)](STREAMING_ARCHITECTURE.md)
- Strict focus: 192.168.86.30 (GPU), .20 (frontend), .19 (Redis), .25 (Web UI)
- Unbuffered pass-through for `/v1/*` and optional `/api/ollama/*`; Nginx directives; raw stream verification

### [Streaming Data-Plane](docs/STREAMING_DATA_PLANE.md)
- **Who owns SSE/WS**: NODE-03–06 (edge stream); OKOME .25 = control plane only (no per-token relay)
- Buffering, retry, backpressure; runtime contract for NODE-01/02, 03–06, 07/08, 09/10

### [GPU Resource Arbitration](docs/GPU_RESOURCE_ARBITRATION.md)
- **TF vs vLLM vs Ollama on .30**: Mode A (shared GPU with limits) vs Mode B (partitioned); load-shed, health, failure modes

### [Next-Phase Action Plan](docs/NEXT_PHASE_ACTION_PLAN.md)
- Gaps closed by STREAMING_DATA_PLANE and GPU_RESOURCE_ARBITRATION; brutal risk list; Phase 1–3 (streaming correct, TF stable, SLOs)

### [Infrastructure Reference (ingested GPU/SSH context)](docs/INFRASTRUCTURE_REFERENCE.md)
- GPU host 192.168.86.30: SSH user (nervcentre), ports (vLLM 8000, Ollama 11434, TensorFlow 8500/8501), verification curl, RDP; pointer to OKOME repo for full optimization/persistence

### [Distributed 10-Node Architecture](docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md)
- CORE GPU (.30) + EDGE nodes 41–50: NODE-01/02 Ingress/Router, NODE-03–06 Cache/Stream, NODE-07/08 Speculative GPU, NODE-09/10 Observability; base config (Ubuntu LTS, governor, network, fd); integration with OKOME .25
- **Enforced**: `configs/edge-nodes/sysctl-99-okome-distributed.conf`, `limits-99-okome.conf`; `scripts/edge-nodes/apply-base-config.sh`, `apply-role-ingress.sh`, `apply-role-cache-stream.sh`, `apply-role-speculative-gpu.sh`, `apply-role-observability.sh`; **`scripts/edge-nodes/deploy-edge-nodes.sh`** (orchestrator: SSHs to 41–50 and applies base + role per node)

### [TensorFlow Integration — GPU Host (.30) and OKOME (.25)](docs/GPU_HOST_TENSORFLOW_INTEGRATION.md)
- TensorFlow (TF Serving 8500/8501) on 192.168.86.30; OKOME .25 config (`TENSORFLOW_SERVING_URL`); verification; integration with 10-node EDGE layer
- **Enforced**: `scripts/tensorflow-serving/install-tensorflow-serving-192.168.86.30.sh`, `verify-tensorflow-serving.sh`; `configs/okome-env/okome-tensorflow.env.example`; `scripts/okome-env/ensure-firewall-25-to-30.sh` (run on .30)

## Quick Start

1. **Review Phase 0**: Set up golden image with SD hardening
2. **Deploy Phase 1**: Basic two-node setup
3. **Enhance Phase 2**: Add health checks and observability
4. **Integrate Phase 3**: Connect Redis to OKOME planner
5. **Enable Phase 4**: Advanced features (canary, pre-warm)
6. **Harden Phase 5**: Enterprise features (VIP, security)
7. **Document Phase 6**: SRE runbook for operations

## Directory Structure

```
cache_nodes_012426_2236/
├── README.md                          # This file
├── 00_FOUNDATION.md                   # SD hardening guide
├── 01_BASIC_SETUP.md                  # Two-node deployment
├── 02_FAILOVER_OBSERVABILITY.md       # Health checks & monitoring
├── 03_CACHE_PLANNER.md                # Redis integration
├── 04_ADVANCED_FEATURES.md            # Canary, pre-warm, budgets
├── 05_ENTERPRISE_HARDENING.md         # VIP, security, chaos
├── 06_SRE_RUNBOOK.md                  # Incident response
├── configs/                           # All configuration files
├── scripts/                           # Deployment and utility scripts
├── code/                              # Python integration code
├── dashboards/                        # Grafana dashboards
└── docs/                              # Additional documentation
```

## Key Features

- **Stateless & Disposable**: Both nodes can be rebuilt in < 15 minutes
- **SD-Friendly**: Minimal writes, RAM-only logs, tmpfs mounts
- **Health-Gated Failover**: Automatic stale cache serving on upstream failure
- **Observability**: Comprehensive headers and hit ratio monitoring
- **Cache-Aware**: Planner short-circuiting with stampede locks
- **Budget Enforcement**: Per-agent rate limits and write budgets
- **Canary Policies**: A/B testing for cache configurations
- **Predictive Pre-warming**: Automatic cache warming from access patterns
- **VIP Failover**: High availability with keepalived
- **Chaos Testing**: Safe failure injection for validation

## Network Configuration

| Node | IP | Role | Service |
|------|-----|------|---------|
| VIP | 192.168.86.18 | Virtual IP | keepalived |
| Frontend | 192.168.86.20 | Edge Cache | Nginx |
| Backend | 192.168.86.19 | Model Cache | Redis |
| Orchestrator | 192.168.86.25:8000 | Upstream | OKOME |

## Cache Key Schema

```
okome:model_meta:{model}
okome:planner:{model}:{prompt_hash}:{toolset}:{repo_hash}
okome:rag:{repo}:{chunk_hash}
okome:tools:{tool_version}
okome:health:{node}
okome:budget:rl:{agent}:{window}
okome:budget:writes:{agent}:{window}
okome:agentkeys:{agent}
```

## TTL Standards

| Cache Type | TTL |
|------------|-----|
| Model metadata | 24h |
| Planner outputs | 5-15 min |
| RAG chunks | 30-60 min |
| Tool discovery | 10 min |
| Health | 30 sec |

## Important Notes

- **VIP Clarification**: The VIP (192.168.86.18) is NOT a separate Raspberry Pi. It's a virtual IP managed by keepalived that floats between the active and backup frontend nodes.
- **Storage**: Both nodes require 32GB A1-rated microSD cards for optimal performance and longevity.
- **No Clustering**: This is a simple active/backup setup. No Redis clustering, no sync, no split-brain scenarios.
- **Stateless Design**: Both cache nodes are disposable. Cache loss is safe and regenerable.

## Related Documentation

- [KOME Main README](../README.md)
- [KOME Architecture](../ARCHITECTURE.md)
- [Backend Caching Guide](../docs/guides/backend-caching.md)

---

**Last Updated**: 2026-01-24
