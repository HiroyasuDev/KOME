# OKOME Two-Node Cache Architecture

Plan: **okome_two-node_cache_architecture_implementation**

## Overview

Two-node production cache:

- **Frontend** (192.168.86.20): Nginx edge cache, upstream 192.168.86.25:8000  
- **Backend** (192.168.86.19): Redis model cache (192.168.86.19:6379)

```
Browser → 192.168.86.20 (Nginx) → 192.168.86.25:8000 (Orchestrator) → 192.168.86.19 (Redis) → GPU
```

## Quick Start

```bash
# Deploy backend (CN01, 192.168.86.19) – password ussfitzgerald
./scripts/deploy_backend_production.sh 192.168.86.19

# Deploy frontend (CN00, 192.168.86.20) – password usshopper
./scripts/deploy_frontend_production.sh 192.168.86.20

# One-command validation (both nodes)
./scripts/okome-validate.sh
```

See **[READY.md](READY.md)** for access details, verification commands, and production checklist.

## Docs

| Doc | Description |
|-----|-------------|
| [00_FOUNDATION.md](00_FOUNDATION.md) | SD hardening, journald, sysctl, golden image |
| [01_BASIC_SETUP.md](01_BASIC_SETUP.md) | Two-node deployment |
| [02_FAILOVER_OBSERVABILITY.md](02_FAILOVER_OBSERVABILITY.md) | Health checks, failover |
| [03_CACHE_PLANNER.md](03_CACHE_PLANNER.md) | Redis, cache.py, budget.py |
| [04_ADVANCED_FEATURES.md](04_ADVANCED_FEATURES.md) | Canary, pre-warm, budgets |
| [05_ENTERPRISE_HARDENING.md](05_ENTERPRISE_HARDENING.md) | VIP, SSH, fail2ban, chaos |
| [06_SRE_RUNBOOK.md](06_SRE_RUNBOOK.md) | Incident response |
| [docs/STORAGE_SPEC.md](docs/STORAGE_SPEC.md) | Storage (32GB A1 microSD) |
| [docs/VIP_CLARIFICATION.md](docs/VIP_CLARIFICATION.md) | VIP 192.168.86.18 |

## Layout

```
configs/
  nginx-frontend/   okome-frontend.conf
  redis-backend/    redis.conf
  sysctl-okome.conf, journald-okome.conf
scripts/
  install_frontend_cache.sh, install_backend_cache.sh
  deploy_backend_production.sh, deploy_frontend_production.sh
  reconfigure_backend_production.sh
  verify.sh, verify_backend.sh, okome-validate.sh
  create-golden-image.sh
code/okome/         cache.py, budget.py, planner_example.py (stubs)
docs/               STORAGE_SPEC.md, VIP_CLARIFICATION.md
```

## Status

- [x] **Backend (192.168.86.19, CN01)**: Redis, static IP, production hardening, `verify_backend.sh`  
- [x] **Frontend (192.168.86.20, CN00)**: Nginx, okome-frontend.conf, `verify_frontend.sh`  
- [x] **Validation**: `verify.sh`, `verify_frontend.sh`, `verify_backend.sh`, `okome-validate.sh` – all pass  
- [x] **Access**: usshopper (CN00), ussfitzgerald (CN01). See [READY.md](READY.md).  
- [ ] Phase 2–6 full: failover, planner, advanced, enterprise, SRE runbook  
