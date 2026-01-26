# Gaps and Incomplete Items — CN00 & CN01

**Date**: 2026-01-25  
**Scope**: OKOME two-node cache (CN00 frontend 192.168.86.20, CN01 backend 192.168.86.19).

---

## CN00 (Frontend) — Gaps & Incomplete

### 1. **Static IP not applied by install**
- **Gap**: `install_frontend_cache.sh` does **not** configure static IP 192.168.86.20. It only disables bluetooth/avahi, installs Nginx, deploys config, logrotate.
- **Impact**: CN00 may stay on DHCP. `verify_frontend.sh` only **WARN**s if 192.168.86.20 is not on eth0; it does not fail.
- **Fix**: Add static-IP logic to `install_frontend_cache.sh` (NetworkManager / dhcpcd), mirroring `install_backend_cache.sh`, or provide a separate `reconfigure_frontend_production.sh` that sets it.

### 2. **No journald / sysctl hardening on CN00**
- **Gap**: Phase 0 (00_FOUNDATION) specifies journald RAM-only and sysctl tweaks for **both** nodes. Only CN01 gets them via `reconfigure_backend_production.sh`. CN00 has no equivalent.
- **Impact**: Frontend still uses default journald (disk) and no sysctl tuning; higher SD wear, less optimal network params.
- **Fix**: Add `reconfigure_frontend_production.sh` that applies `journald-okome.conf` and `sysctl-okome.conf`, or extend `install_frontend_cache.sh` to do so. Ensure `deploy_frontend_production.sh` uses it (or runs those steps).

### 3. **Hostname not set by automation**
- **Gap**: Phase 0 specifies hostname **CN00** (frontend) / **CN01** (backend). No install or deploy script sets `hostnamectl set-hostname CN00` (or CN01).
- **Impact**: Nodes may keep default hostnames (e.g. `raspberrypi`), which can confuse operators and logs.
- **Fix**: Set hostname in `install_frontend_cache.sh` (CN00) and `install_backend_cache.sh` / `reconfigure_backend_production.sh` (CN01). Document in 01_BASIC_SETUP.

### 4. **Phase 2–6 frontend deliverables not implemented**
- **Gap**: The following are **stubs** or **unimplemented**; they affect or could affect CN00:
  - **Phase 2**: Health probe timer, Nginx health-state include (`/etc/nginx/okome/health_state.conf`), stale-cache-on-upstream-failure behavior, custom log format, hit-ratio scripts. `okome-health-probe.sh`, `okome-health-probe.service`/`.timer`, `calculate-hit-ratio.sh` are stubs.
  - **Phase 4**: Canary maps/policies, pre-warm script/timer. `canary_maps.conf`, `canary_policies.conf`, `okome-prewarm.sh`, `okome-prewarm.service`/`.timer` are stubs.
  - **Phase 5**: Keepalived VIP, node-exporter, SSH hardening, fail2ban, optional Grafana. Configs are stubs.
- **Impact**: No health-gated failover, no pre-warm, no VIP, no observability beyond X-Cache-Status.
- **Fix**: Implement per plan in 02_FAILOVER_OBSERVABILITY, 04_ADVANCED_FEATURES, 05_ENTERPRISE_HARDENING.

### 5. **Fstab (optional)**
- **Gap**: `00_FOUNDATION` mentions optional tmpfs for `/var/cache/nginx` (frontend) and `noatime`/`commit=60` on root. Not applied by any script.
- **Impact**: None if skipped; optionally less SD wear if applied.
- **Fix**: Document clearly as optional; add fstab merge to install or a separate "Phase 0 optional" script if desired.

---

## CN01 (Backend) — Gaps & Incomplete

### 1. **Fresh-node deploy: Redis install vs reconfig**
- **Gap**: `deploy_backend_production.sh` runs **only** `reconfigure_backend_production.sh`. Reconfig does **not** install Redis (`apt-get install redis-server`). It deploys config, journald, sysctl, logrotate, restarts Redis. On a **fresh** CN01, Redis is not installed, so deploy fails.
- **Impact**: READY and 01_BASIC_SETUP say "run deploy_backend_production" for backend. That is insufficient for a fresh Pi.
- **Fix**: Either (a) have `deploy_backend_production.sh` run `install_backend_cache.sh` first when Redis is missing, or (b) document clearly: "Fresh CN01: run `deploy_backend_to_cn01` (or `install_backend_cache`) first, then `deploy_backend_production`." Update READY and 01_BASIC_SETUP.

### 2. **Hostname not set by automation**
- **Gap**: Same as CN00; no script sets **CN01** on the backend.
- **Fix**: Set in `install_backend_cache.sh` or `reconfigure_backend_production.sh`; document.

### 3. **Phase 2–6 backend deliverables not implemented**
- **Gap**: Backend-related stubs / unimplemented:
  - **Phase 2**: Health probe, observability (e.g. X-Upstream, X-Request-ID from Nginx; backend health checks). `okome-health-probe` is stub.
  - **Phase 3**: `cache.py`, `budget.py`, planner integration. Code stubs only; TODO: Redis connection, keys, TTL; rate limits; etc.
  - **Phase 5**: Keepalived (VIP), node-exporter, SSH/fail2ban, optional chaos testing. Configs stubs.
- **Impact**: No planner cache integration, no health-gated VIP, no structured observability.
- **Fix**: Implement per 02_FAILOVER_OBSERVABILITY, 03_CACHE_PLANNER, 05_ENTERPRISE_HARDENING.

### 4. **Fstab (optional)**
- **Gap**: Same as CN00; optional fstab tweaks not applied.
- **Fix**: As for CN00; optional.

### 5. **verify_backend.sh message bug**
- **Gap**: When Redis ping **fails**, the script prints `FAIL: Redis PONG` instead of `FAIL: Redis no PONG` or `FAIL: Redis ping failed`.
- **Impact**: Misleading log message during failures.
- **Fix**: Change the else-branch message to e.g. `FAIL: Redis ping failed` (or `no PONG`).

---

## Shared / Both Nodes

### 1. **Phase 0 raspi-config**
- **Gap**: 00_FOUNDATION references raspi-config (hostname, GPU memory 16–32 MB, etc.). No automation runs `raspi-config` or equivalent.
- **Impact**: Operators must configure manually; golden-image process is less reproducible.
- **Fix**: Document exact raspi-config steps; optionally add a small wrapper script that runs non-interactive raspi-config if available.

### 2. **Golden image**
- **Gap**: `create-golden-image.sh` only **prints** steps (echo). It does not image the SD, set IP/hostname on a cloned node, or re-run deploys.
- **Impact**: Golden-image procedure is manual.
- **Fix**: Implement helpers (e.g. `dd` imaging, hostname/IP setup per node, re-deploy) or clearly document as "documentation-only" and add a separate automation script later.

### 3. **Phase 6 SRE runbook**
- **Gap**: 06_SRE_RUNBOOK is a stub. Incident procedures (UI slow/blank, Redis down, VIP not responding, Pi dead, upstream down, cache-miss storm, chaos) are not written.
- **Impact**: No formal runbook for operations.
- **Fix**: Implement 06_SRE_RUNBOOK per plan; keep `okome-validate.sh` as the one-command validation.

### 4. **Code stubs (Phase 3)**
- **Gap**: `code/okome/cache.py`, `budget.py`, `planner_example.py` are stubs with TODOs:
  - `cache.py`: TODO: Redis connection, cache keys (planner, RAG, model meta), TTL.
  - `budget.py`: TODO: Rate limiting per agent, cache write budget, cardinality caps.
  - `planner_example.py`: TODO: Use cache.py + budget.py; stampede locks; X-OKOME-Cache headers.
- **Impact**: No planner cache integration; orchestrator cannot use backend cache.
- **Fix**: Implement per 03_CACHE_PLANNER; integrate with OKOME orchestrator.

### 5. **Observability gaps**
- **Gap**: Phase 2 specifies custom Nginx log format, hit-ratio scripts, X-Upstream, X-Request-ID headers. Only X-Cache-Status and X-OKOME-Node are implemented.
- **Impact**: Limited observability; no hit-ratio tracking, no request correlation.
- **Fix**: Implement custom log format, `calculate-hit-ratio.sh`, add X-Upstream/X-Request-ID to Nginx config.

### 6. **SSH / fail2ban (Phase 5)**
- **Gap**: `configs/ssh/sshd_config` and `configs/fail2ban/jail.local` are stubs. No SSH hardening or fail2ban deployed.
- **Impact**: Nodes vulnerable to brute-force; SSH not hardened.
- **Fix**: Implement SSH config (key-only, disable root, etc.), fail2ban jail (RAM-only, SSH), deploy via Phase 5 script.

### 7. **Keepalived VIP (Phase 5)**
- **Gap**: `configs/keepalived/keepalived-master.conf` and `keepalived-backup.conf` are stubs. No VIP (192.168.86.18) configured.
- **Impact**: No high-availability frontend; single point of failure.
- **Fix**: Implement keepalived configs, health check integration, deploy to both frontend nodes (when second CN00 exists).

### 8. **Node exporter / Grafana (Phase 5)**
- **Gap**: `configs/systemd/node-exporter.service` is stub; `dashboards/grafana/okome-cache-hitmiss.json` is stub. No Prometheus metrics or Grafana dashboard.
- **Impact**: No structured metrics; no dashboard for cache hit/miss.
- **Fix**: Implement node-exporter (RAM-safe), Grafana dashboard JSON, deploy per Phase 5.

### 9. **Chaos testing (Phase 5)**
- **Gap**: `scripts/okome-chaos.sh` is stub. No chaos testing framework.
- **Impact**: No resilience testing.
- **Fix**: Implement chaos script (network partition, Redis kill, Nginx restart, etc.) with CHAOS_ENABLE guard.

### 10. **Canary / pre-warm (Phase 4)**
- **Gap**: `configs/nginx-frontend/canary_maps.conf`, `canary_policies.conf`, `scripts/okome-prewarm.sh`, `okome-prewarm.service`/`.timer` are stubs.
- **Impact**: No canary deployments; no cache pre-warming.
- **Fix**: Implement canary maps (header/cookie-based), policies (control/canary/debug), pre-warm script (analyze logs, warm top N URLs), systemd timer.

### 11. **Documentation gaps**
- **Gap**: Phase 2–6 docs (02_FAILOVER_OBSERVABILITY, 03_CACHE_PLANNER, 04_ADVANCED_FEATURES, 05_ENTERPRISE_HARDENING, 06_SRE_RUNBOOK) are stubs with "Status: Stub. Implement per plan."
- **Impact**: No detailed procedures for advanced features.
- **Fix**: Write full documentation per plan; include deploy steps, configs, verification.

### 12. **Deploy script inconsistencies**
- **Gap**: 
  - `deploy_backend_to_cn01.sh` runs `install_backend_cache.sh` (fresh install).
  - `deploy_backend_production.sh` runs `reconfigure_backend_production.sh` (reconfig only, assumes Redis installed).
  - No equivalent `deploy_frontend_to_cn00.sh` for fresh install; only `deploy_frontend_production.sh` which runs `install_frontend_cache.sh`.
- **Impact**: Backend has two deploy paths (fresh vs reconfig); frontend has one. Inconsistent.
- **Fix**: Either unify (e.g. `deploy_backend_production.sh` detects fresh vs existing and calls install or reconfig), or document clearly: "Fresh: use deploy_backend_to_cn01; existing: use deploy_backend_production."

---

## Summary

**Phase 1 (Basic Setup)**: ✅ **Complete** — Both nodes operational, Redis + Nginx deployed, static IPs set (CN01 via reconfig; CN00 manual or missing), basic verification works.

**Phase 0 (Foundation)**: ⚠️ **Partial** — Journald/sysctl on CN01 only; hostname not set; raspi-config manual; fstab optional (not applied).

**Phase 2–6**: ❌ **Stubs** — All advanced features, observability, failover, planner integration, enterprise hardening, SRE runbook are unimplemented.

**Critical gaps for production**:
1. CN00 static IP not automated.
2. CN00 journald/sysctl missing.
3. Fresh CN01 deploy unclear (install vs reconfig).
4. Hostname not set on either node.
5. verify_backend.sh message bug.

**Next steps**: Address Phase 1 gaps first (static IP CN00, journald/sysctl CN00, hostname, fresh-deploy clarity), then proceed with Phase 2–6 implementation.

---

**Last updated**: 2026-01-25
