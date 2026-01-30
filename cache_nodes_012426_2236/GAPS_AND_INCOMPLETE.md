# Gaps and Incomplete Items — CN00 & CN01

**Date**: 2026-01-25  
**Scope**: OKOME two-node cache (CN00 frontend 192.168.86.20, CN01 backend 192.168.86.19).

---

## CN00 (Frontend) — Gaps & Incomplete

### 1. **Static IP not applied by install** — **Resolved**
- **Gap**: `install_frontend_cache.sh` did not configure static IP 192.168.86.20.
- **Fix applied**: Static-IP logic (NetworkManager / dhcpcd) added to `install_frontend_cache.sh`; `reconfigure_frontend_production.sh` also sets it.

### 2. **No journald / sysctl hardening on CN00** — **Resolved**
- **Gap**: CN00 had no journald/sysctl equivalent to backend.
- **Fix applied**: `reconfigure_frontend_production.sh` added; applies `journald-okome.conf` and `sysctl-okome.conf`. `deploy_frontend_production.sh` runs install then reconfigure.

### 3. **Hostname not set by automation** — **Resolved**
- **Gap**: No script set hostname CN00 / CN01.
- **Fix applied**: `install_frontend_cache.sh` and `reconfigure_frontend_production.sh` set CN00; `install_backend_cache.sh` and `reconfigure_backend_production.sh` set CN01. Documented in 01_BASIC_SETUP.

### 4. **Phase 2–6 frontend deliverables** — **Resolved**
- **Fix applied**: Phase 2 (health probe, health_state, log format, hit-ratio), Phase 4 (canary, pre-warm), Phase 5 (keepalived, node-exporter, SSH, fail2ban, chaos, Grafana) implemented. See 02_FAILOVER_OBSERVABILITY, 04_ADVANCED_FEATURES, 05_ENTERPRISE_HARDENING. `deploy_frontend_production` scps `health_state.conf.default`, `okome-health-include.conf`, `canary_maps.conf`, `canary_policies.conf` so install deploys full Phase 2/4 nginx config.

### 5. **Fstab (optional)** — **Resolved**
- **Fix applied**: Documented as optional in 00_FOUNDATION; `scripts/apply-fstab-optional.sh` adds tmpfs line with backup. Root noatime/commit=60 merge manually.

---

## CN01 (Backend) — Gaps & Incomplete

### 1. **Fresh-node deploy: Redis install vs reconfig** — **Resolved**
- **Gap**: `deploy_backend_production.sh` only ran reconfig; fresh CN01 failed.
- **Fix applied**: `deploy_backend_production.sh` detects missing Redis, runs `install_backend_cache.sh` first (nohup), then reconfig. Single script for fresh or existing. READY and 01_BASIC_SETUP updated.

### 2. **Hostname not set by automation** — **Resolved**
- **Gap**: No script set CN01 on backend.
- **Fix applied**: `install_backend_cache.sh` and `reconfigure_backend_production.sh` set hostname CN01; documented.

### 3. **Phase 2–6 backend deliverables** — **Resolved**
- **Fix applied**: Phase 2–5 implemented (health probe, observability, cache/budget/planner, keepalived, node-exporter, SSH, fail2ban, chaos). See 02, 03, 05.

### 4. **Fstab (optional)** — **Resolved**
- Same as CN00; optional. `apply-fstab-optional.sh` available.

### 5. **verify_backend.sh message bug** — **Resolved**
- **Gap**: On Redis ping failure, script printed `FAIL: Redis PONG`.
- **Fix applied**: Else-branch now prints `FAIL: Redis ping failed`.

---

## Shared / Both Nodes

### 1. **Phase 0 raspi-config** — **Resolved**
- **Fix applied**: 00_FOUNDATION documents exact steps; `scripts/raspi-config-okome.sh` provides hostname/gpu helpers.

### 2. **Golden image** — **Resolved**
- **Fix applied**: `create-golden-image.sh` marked documentation-only; `--print-dd` outputs sample dd commands.

### 3. **Phase 6 SRE runbook** — **Resolved**
- **Fix applied**: 06_SRE_RUNBOOK.md has procedures for all seven incident types, golden rules, okome-validate reference.

### 4. **Code stubs (Phase 3)** — **Resolved**
- **Fix applied**: cache.py, budget.py, planner_example.py implemented; Redis, keys, TTL, rate limits, stampede lock, X-OKOME-Cache headers.

### 5. **Observability gaps** — **Resolved**
- **Fix applied**: okome_fmt log format, calculate-hit-ratio.sh, X-Upstream, X-Request-ID in Nginx.

### 6. **SSH / fail2ban (Phase 5)** — **Resolved**
- **Fix applied**: sshd_config merge instructions; fail2ban jail.local (SSH). Deploy per 05_ENTERPRISE_HARDENING.

### 7. **Keepalived VIP (Phase 5)** — **Resolved**
- **Fix applied**: keepalived-master/backup configs, okome-keepalived-check.sh. Deploy when second frontend exists.

### 8. **Node exporter / Grafana (Phase 5)** — **Resolved**
- **Fix applied**: node-exporter.service (RAM-safe); okome-cache-hitmiss.json. Deploy per 05.

### 9. **Chaos testing (Phase 5)** — **Resolved**
- **Fix applied**: okome-chaos.sh (nginx-stop/start, redis-stop/start), CHAOS_ENABLE guard.

### 10. **Canary / pre-warm (Phase 4)** — **Resolved**
- **Fix applied**: canary_maps, canary_policies, okome-prewarm.sh, systemd timer. See 04_ADVANCED_FEATURES.

### 11. **Documentation gaps** — **Resolved**
- **Fix applied**: 02–06 docs expanded with procedures, deploy steps, verification.

### 12. **Deploy script inconsistencies** — **Resolved**
- **Gap**: Backend had two paths (fresh vs reconfig); frontend only install.
- **Fix applied**: `deploy_backend_production.sh` unifies: install-if-missing then reconfig. Frontend deploy runs install + reconfigure. `deploy_backend_to_cn01` retained as optional fresh-only; documented in READY.

---

## Summary

**Phase 1 (Basic Setup)**: ✅ **Complete** — Both nodes operational, Redis + Nginx deployed, static IPs set by install/reconfig, hostname CN00/CN01 set, basic verification works.

**Phase 0 (Foundation)**: ✅ **Improved** — Journald/sysctl applied on **both** CN00 and CN01 via reconfigure scripts; hostname set. Raspi-config remains manual; fstab optional (not applied).

**Phase 2–6**: ✅ **Implemented** — Health probe, observability, planner code, canary/pre-warm, enterprise hardening, SRE runbook, optional Phase 0 (fstab, raspi-config, golden-image) are in place.

**Critical gaps (Phase 0/1) — resolved**:
1. ~~CN00 static IP not automated~~ → Done in install + reconfigure.
2. ~~CN00 journald/sysctl missing~~ → `reconfigure_frontend_production.sh` + deploy.
3. ~~Fresh CN01 deploy unclear~~ → `deploy_backend_production` install-if-missing.
4. ~~Hostname not set~~ → Set in install + reconfigure for both nodes.
5. ~~verify_backend.sh message bug~~ → Fixed.

**Next steps**: Deploy Phase 2–5 components (health probe, pre-warm, canary, keepalived when second frontend exists) per 02–05 docs. Run `okome-validate` and use 06_SRE_RUNBOOK for incidents.

---

## Path through OKOME .25 + full throughput/failures (2026-01-30)

- **Path through 192.168.86.25 only**: All traffic goes through OKOME at .25. Nginx on .20 has a single upstream `okome_upstream` (192.168.86.25:8000). No direct proxy to .30 from KOME; OKOME on .25 talks to GPU (.30) and Redis (.19) internally.
- **Throughput**: API/stream locations use `proxy_buffering off`, `proxy_request_buffering off`, `chunked_transfer_encoding on`, `proxy_read_timeout 600s`, `proxy_send_timeout 600s`, `keepalive 64`, and `proxy_next_upstream error timeout http_502 http_503 http_504` with `proxy_next_upstream_tries 2`.
- **Failures**: Health probe checks .25/health; static locations use `proxy_cache_use_stale` and `error_page 502 503 504 = @okome_maintenance`; maintenance returns 503 + Retry-After. Health default: `set $okome_upstream_ok 1` in health_state.conf.default.
- **Docs**: [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md), [docs/INFRASTRUCTURE_REFERENCE.md](docs/INFRASTRUCTURE_REFERENCE.md), ARCHITECTURE.md, and README updated for path-through-.25.

---

**Last updated**: 2026-01-30
