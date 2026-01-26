# Phase 5: Enterprise Hardening

**Status**: Stub. Implement per plan.

- Keepalived VIP (192.168.86.18): active/backup, health check integration
- Prometheus node exporter (RAM-safe)
- SSH hardening (key-only), fail2ban (RAM-only, SSH)
- Optional WireGuard, chaos testing (okome-chaos.sh, CHAOS_ENABLE guard)
- Grafana dashboard (optional)

**Deliverables**: `configs/keepalived/`, `configs/systemd/node-exporter.service`, `configs/ssh/sshd_config`, `configs/fail2ban/jail.local`, `scripts/okome-chaos.sh`, `dashboards/grafana/okome-cache-hitmiss.json`.
