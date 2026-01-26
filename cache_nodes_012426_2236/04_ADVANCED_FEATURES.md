# Phase 4: Advanced Features

**Status**: Stub. Implement per plan.

- Canary policies (header/cookie), control/canary/debug, per-endpoint TTL, cache key versioning
- Pre-warm script: analyze Nginx logs, top N URLs, warm requests
- Budget enforcement in planner: agent rate limits (60/min), cache writes (30/min), cardinality caps (5000 keys/agent)
- Systemd timer for pre-warm (every 2 min)

**Deliverables**: `configs/nginx-frontend/canary_maps.conf`, `canary_policies.conf`, `scripts/okome-prewarm.sh`, `configs/systemd/okome-prewarm.service` / `.timer`.
