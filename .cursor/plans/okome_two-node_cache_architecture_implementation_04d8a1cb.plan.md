---
name: OKOME Two-Node Cache Architecture Implementation
overview: Transform KOME from a single frontend cache node to a production-grade two-node architecture with Frontend/Edge Cache (Nginx) and Backend/Model Cache (Redis), including health-gated failover, cache-aware planner, observability, canary policies, pre-warming, budget enforcement, and comprehensive SRE runbook.
todos:
  - id: phase0-foundation
    content: "Phase 0: Create foundation documentation and SD hardening configs (fstab, sysctl, journald, golden image procedure)"
    status: completed
  - id: phase1-basic-setup
    content: "Phase 1: Create two-node basic setup (Nginx frontend config, Redis backend config, deployment scripts)"
    status: completed
  - id: phase2-failover
    content: "Phase 2: Implement health-gated failover (health probe, systemd timers, maintenance fallback, observability headers)"
    status: completed
  - id: phase3-cache-planner
    content: "Phase 3: Create cache-aware planner integration (cache.py, budget.py, planner example, rate limiting)"
    status: completed
  - id: phase4-advanced
    content: "Phase 4: Add advanced features (canary policies, pre-warming script, budget enforcement integration)"
    status: completed
  - id: phase5-enterprise
    content: "Phase 5: Enterprise hardening (keepalived VIP, Prometheus exporter, SSH hardening, fail2ban, chaos testing)"
    status: completed
  - id: phase6-sre-runbook
    content: "Phase 6: Create comprehensive SRE runbook with all 7 incident types and operational procedures"
    status: completed
  - id: create-directory
    content: Create cache_nodes_012426_2236 directory structure with all subdirectories
    status: completed
  - id: create-readme
    content: Create README.md index file for cache_nodes_012426_2236 with navigation and overview
    status: completed
---

# OKOME Two-Node Cache Architecture Implementation Plan

## Current State

- Single frontend cache node at 192.168.86.20 (Nginx only)
- Basic caching for static assets (`/assets/`, `/ui-schema/`, `/version/`)
- No backend caching, no Redis, no health checks, no failover

## Target Architecture

```
Browser
   ↓
192.168.86.18 (VIP - managed by keepalived)
   ↓
192.168.86.20 (Frontend/Edge Cache - Nginx)
   ↓
192.168.86.25:8000 (OKOME Orchestrator)
   ↓
192.168.86.19 (Backend/Model Cache - Redis)
   ↓
GPU Node (Inference only)
```

## Implementation Phases

### Phase 0: Foundation & SD Hardening

**Goal**: Create golden image with SD wear reduction for both cache nodes

**Tasks**:

- Create `cache_nodes_012426_2236/00_FOUNDATION.md` with SD hardening guide
- Document raspi-config settings (hostname, GPU memory, interfaces)
- Create fstab configuration (noatime, commit=60, tmpfs mounts)
- Document journald RAM-only configuration
- Create service pruning script (disable bluetooth, avahi, etc.)
- Document kernel/filesystem tweaks (sysctl.conf)
- Create golden image cloning procedure
- Document filesystem mount options for SD longevity

**Deliverables**:

- `cache_nodes_012426_2236/00_FOUNDATION.md`
- `cache_nodes_012426_2236/configs/fstab-hardened.conf`
- `cache_nodes_012426_2236/configs/sysctl-okome.conf`
- `cache_nodes_012426_2236/configs/journald.conf`
- `cache_nodes_012426_2236/scripts/create-golden-image.sh`

### Phase 1: Two-Node Basic Setup

**Goal**: Deploy basic two-node architecture (Nginx frontend + Redis backend)

**Tasks**:

- Create `cache_nodes_012426_2236/01_BASIC_SETUP.md` with deployment guide
- Create enhanced Nginx config for frontend node (192.168.86.20)
  - Update cache path to `/var/cache/nginx/okome`
  - Increase cache size to 2GB
  - Add observability headers (X-Cache-Status, X-OKOME-Node)
- Create Redis configuration for backend node (192.168.86.19)
  - Configure bind to 127.0.0.1 and 192.168.86.19
  - Set maxmemory 4GB with allkeys-lru policy
  - Disable persistence (appendonly no, save "")
- Create deployment scripts for both nodes
- Update orchestrator upstream from 192.168.86.25:3000 to 192.168.86.25:8000

**Deliverables**:

- `cache_nodes_012426_2236/01_BASIC_SETUP.md`
- `cache_nodes_012426_2236/configs/nginx-frontend/okome-frontend.conf`
- `cache_nodes_012426_2236/configs/redis-backend/redis.conf`
- `cache_nodes_012426_2236/scripts/install_frontend_cache.sh`
- `cache_nodes_012426_2236/scripts/install_backend_cache.sh`
- `cache_nodes_012426_2236/scripts/verify.sh`

### Phase 2: Health-Gated Failover & Observability

**Goal**: Add active health checks, failover logic, and comprehensive observability

**Tasks**:

- Create `cache_nodes_012426_2236/02_FAILOVER_OBSERVABILITY.md`
- Implement health probe systemd timer (checks upstream every 5s)
- Create Nginx health state include file (`/etc/nginx/okome/health_state.conf`)
- Add maintenance fallback endpoint
- Implement stale cache serving on upstream failure
- Add comprehensive observability headers (X-Cache-Status, X-Upstream, X-Request-ID)
- Create custom Nginx log format for cache analysis
- Add Nginx status page (LAN-only access)
- Create hit ratio calculation scripts

**Deliverables**:

- `cache_nodes_012426_2236/02_FAILOVER_OBSERVABILITY.md`
- `cache_nodes_012426_2236/configs/nginx-frontend/okome-frontend-hardened.conf`
- `cache_nodes_012426_2236/scripts/okome-health-probe.sh`
- `cache_nodes_012426_2236/configs/systemd/okome-health-probe.service`
- `cache_nodes_012426_2236/configs/systemd/okome-health-probe.timer`
- `cache_nodes_012426_2236/scripts/calculate-hit-ratio.sh`

### Phase 3: Cache-Aware Planner & Rate Limiting

**Goal**: Integrate Redis cache with OKOME planner and add rate limiting

**Tasks**:

- Create `cache_nodes_012426_2236/03_CACHE_PLANNER.md`
- Create Python cache helper module (`okome/cache.py`)
  - Redis connection with proper timeouts
  - Cache key generation (planner, RAG, model metadata)
  - TTL management per cache type
- Create budget enforcement module (`okome/budget.py`)
  - Rate limiting per agent
  - Cache write budget enforcement
  - Cardinality capping
- Update planner endpoint to use cache with stampede locks
- Add cache headers to responses (X-OKOME-Cache, X-OKOME-Cache-Key)
- Enhance Nginx rate limiting (separate zones for UI vs API)
- Add connection limits

**Deliverables**:

- `cache_nodes_012426_2236/03_CACHE_PLANNER.md`
- `cache_nodes_012426_2236/code/okome/cache.py`
- `cache_nodes_012426_2236/code/okome/budget.py`
- `cache_nodes_012426_2236/code/okome/planner_example.py` (integration example)
- Updated Nginx config with enhanced rate limiting

### Phase 4: Advanced Features

**Goal**: Add canary policies, predictive pre-warming, and budget enforcement

**Tasks**:

- Create `cache_nodes_012426_2236/04_ADVANCED_FEATURES.md`
- Implement canary cache policies (header/cookie-based)
  - Control/canary/debug modes
  - Per-endpoint TTL overrides
  - Cache key versioning
- Create predictive pre-warm script
  - Analyze Nginx access logs
  - Extract top N URLs
  - Sequential warm requests
- Integrate budget enforcement in planner
  - Agent rate limits (60/min)
  - Cache write limits (30/min)
  - Cardinality caps (5000 keys/agent)
- Create systemd timer for pre-warming (every 2 minutes)

**Deliverables**:

- `cache_nodes_012426_2236/04_ADVANCED_FEATURES.md`
- `cache_nodes_012426_2236/configs/nginx-frontend/canary_maps.conf`
- `cache_nodes_012426_2236/configs/nginx-frontend/canary_policies.conf`
- `cache_nodes_012426_2236/scripts/okome-prewarm.sh`
- `cache_nodes_012426_2236/configs/systemd/okome-prewarm.service`
- `cache_nodes_012426_2236/configs/systemd/okome-prewarm.timer`

### Phase 5: Enterprise Hardening

**Goal**: Add VIP failover, monitoring, security, and chaos testing

**Tasks**:

- Create `cache_nodes_012426_2236/05_ENTERPRISE_HARDENING.md`
- Implement keepalived for VIP failover (192.168.86.18)
  - Active/backup configuration
  - Health check integration
- Add Prometheus node exporter (RAM-safe mode)
- Configure SSH hardening (key-only, no passwords)
- Add fail2ban (RAM-only, SSH-focused)
- Create WireGuard configuration (optional, for secure admin)
- Implement chaos testing framework
  - Safe chaos runner script
  - CHAOS_ENABLE file guard
  - Test scenarios (nginx-stop, redis-stop, vip-failover, etc.)
- Create Grafana dashboard configuration (optional)

**Deliverables**:

- `cache_nodes_012426_2236/05_ENTERPRISE_HARDENING.md`
- `cache_nodes_012426_2236/configs/keepalived/keepalived-master.conf`
- `cache_nodes_012426_2236/configs/keepalived/keepalived-backup.conf`
- `cache_nodes_012426_2236/configs/systemd/node-exporter.service`
- `cache_nodes_012426_2236/configs/ssh/sshd_config`
- `cache_nodes_012426_2236/configs/fail2ban/jail.local`
- `cache_nodes_012426_2236/scripts/okome-chaos.sh`
- `cache_nodes_012426_2236/dashboards/grafana/okome-cache-hitmiss.json`

### Phase 6: SRE Runbook & Documentation

**Goal**: Create comprehensive operational documentation

**Tasks**:

- Create `cache_nodes_012426_2236/06_SRE_RUNBOOK.md` with incident response procedures
- Document all 7 incident types:
  - UI slow/blank
  - Redis unavailable
  - VIP not responding
  - Frontend Pi dead
  - Upstream orchestrator down
  - Cache miss storm
  - Chaos test triggered
- Create operational golden rules
- Document VIP clarification (no separate Pi needed)
- Create validation script for both nodes
- Create one-command validation script
- Document storage specifications (32GB A1 microSD for both nodes)

**Deliverables**:

- `cache_nodes_012426_2236/06_SRE_RUNBOOK.md`
- `cache_nodes_012426_2236/scripts/okome-validate.sh`
- `cache_nodes_012426_2236/docs/STORAGE_SPEC.md`
- `cache_nodes_012426_2236/docs/VIP_CLARIFICATION.md`

## File Structure

```
cache_nodes_012426_2236/
├── README.md                          # Index and overview
├── 00_FOUNDATION.md                   # SD hardening guide
├── 01_BASIC_SETUP.md                  # Two-node deployment
├── 02_FAILOVER_OBSERVABILITY.md       # Health checks & monitoring
├── 03_CACHE_PLANNER.md                # Redis integration
├── 04_ADVANCED_FEATURES.md            # Canary, pre-warm, budgets
├── 05_ENTERPRISE_HARDENING.md         # VIP, security, chaos
├── 06_SRE_RUNBOOK.md                  # Incident response
├── configs/
│   ├── nginx-frontend/
│   │   ├── okome-frontend.conf
│   │   ├── okome-frontend-hardened.conf
│   │   ├── canary_maps.conf
│   │   └── canary_policies.conf
│   ├── redis-backend/
│   │   └── redis.conf
│   ├── keepalived/
│   │   ├── keepalived-master.conf
│   │   └── keepalived-backup.conf
│   ├── systemd/
│   │   ├── okome-health-probe.service
│   │   ├── okome-health-probe.timer
│   │   ├── okome-prewarm.service
│   │   ├── okome-prewarm.timer
│   │   └── node-exporter.service
│   ├── ssh/
│   │   └── sshd_config
│   ├── fail2ban/
│   │   └── jail.local
│   ├── fstab-hardened.conf
│   ├── sysctl-okome.conf
│   └── journald.conf
├── scripts/
│   ├── install_frontend_cache.sh
│   ├── install_backend_cache.sh
│   ├── verify.sh
│   ├── okome-health-probe.sh
│   ├── okome-prewarm.sh
│   ├── okome-chaos.sh
│   ├── okome-validate.sh
│   ├── calculate-hit-ratio.sh
│   └── create-golden-image.sh
├── code/
│   └── okome/
│       ├── cache.py
│       ├── budget.py
│       └── planner_example.py
├── dashboards/
│   └── grafana/
│       └── okome-cache-hitmiss.json
└── docs/
    ├── STORAGE_SPEC.md
    └── VIP_CLARIFICATION.md
```

## Key Configuration Changes

### Frontend Node (192.168.86.20)

- Update upstream to 192.168.86.25:8000 (from :3000)
- Increase cache size to 2GB
- Add health-gated failover logic
- Add canary policy support
- Enhanced rate limiting (UI: 20r/s, API: 5r/s)
- Comprehensive observability headers

### Backend Node (192.168.86.19)

- Redis with 4GB maxmemory
- No persistence (stateless)
- Bind to localhost and node IP
- LRU eviction policy

### VIP (192.168.86.18)

- Managed by keepalived
- Floats between active/backup frontend nodes
- No separate Pi required

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

- Model metadata: 24h
- Planner outputs: 5-15 min
- RAG chunks: 30-60 min
- Tool discovery: 10 min
- Health: 30 sec

## Testing & Validation

- One-command validation script
- Cache hit ratio monitoring
- Health check verification
- VIP failover testing
- Chaos testing framework