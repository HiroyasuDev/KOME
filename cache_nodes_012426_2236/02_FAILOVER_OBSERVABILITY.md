# Phase 2: Health-Gated Failover & Observability

**Status**: Stub. Implement per plan.

- Health probe systemd timer (upstream check every 5s)
- Nginx health state include: `/etc/nginx/okome/health_state.conf`
- Maintenance fallback, stale cache on upstream failure
- Observability headers: X-Cache-Status, X-Upstream, X-Request-ID
- Custom Nginx log format, hit-ratio scripts

**Deliverables**: `configs/nginx-frontend/okome-frontend-hardened.conf`, `scripts/okome-health-probe.sh`, `configs/systemd/okome-health-probe.service` / `.timer`, `scripts/calculate-hit-ratio.sh`.
