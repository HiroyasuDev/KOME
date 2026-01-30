# Phase 4: Advanced Features

**Goal**: Add canary policies, predictive pre-warming, and budget enforcement

**Node**: Frontend Cache (192.168.86.20)

---

## Overview

This phase adds advanced cache management features:
- **Canary Policies**: A/B testing for cache configurations via headers/cookies
- **Predictive Pre-warming**: Automatic cache warming based on access patterns
- **Budget Enforcement**: Already integrated in Phase 3, documented here

## Part A: Canary Cache Policies

### Overview

Canary policies allow you to test different cache configurations without affecting production traffic. Three modes:

- **control**: Normal caching (default)
- **canary**: New TTLs or cache keys
- **debug**: Force bypass to compare performance

### Activation

**Via Header**:
```bash
curl -I -H "X-OKOME-Canary: canary" http://192.168.86.20/ui-schema/foo
```

**Via Cookie**:
```bash
curl -I -H "Cookie: okome_canary=canary" http://192.168.86.20/ui-schema/foo
```

### Configuration

1. Copy `configs/nginx-frontend/canary_maps.conf` to Nginx config directory
2. Copy `configs/nginx-frontend/canary_policies.conf` to Nginx config directory
3. Include both in main Nginx config
4. Reload Nginx

### Example: UI Schema Canary

- **Control**: 24h TTL
- **Canary**: 5m TTL (to validate schema churn)
- **Debug**: No cache (bypass)

### Example: Assets Canary

- **Control**: Cache key v1
- **Canary**: Cache key v2 (for cache busting experiments)
- **Debug**: No cache

## Part B: Predictive Pre-warming

### Overview

The pre-warm script analyzes Nginx access logs to find the hottest URLs and warms the cache proactively.

### Installation

1. Copy `scripts/okome-prewarm.sh` to `/usr/local/bin/`
2. Copy `configs/systemd/okome-prewarm.service` to `/etc/systemd/system/`
3. Copy `configs/systemd/okome-prewarm.timer` to `/etc/systemd/system/`
4. Enable timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now okome-prewarm.timer
```

### Configuration

Edit `/usr/local/bin/okome-prewarm.sh` to adjust:
- `OKOME_WARM_TARGET`: VIP or direct node IP
- `OKOME_WARM_TOP_N`: Number of URLs to warm (default: 40)
- `OKOME_NGINX_LOG`: Log file path

### How It Works

1. Analyzes last Nginx access log entries
2. Extracts request paths matching safe patterns
3. Counts frequency
4. Takes top N URLs
5. Sequentially warms cache (HEAD requests)

### Safe Patterns

Only these endpoints are warmed:
- `/` (root)
- `/assets/*`
- `/static/*`
- `/ui-schema/*`
- `/version`
- `/health`

## Part C: Budget Enforcement

Budget enforcement is implemented in Phase 3 (`code/okome/budget.py`). This section documents usage.

### Default Limits

- **Rate Limit**: 60 requests/minute per agent
- **Write Limit**: 30 cache writes/minute per agent
- **Cardinality Cap**: 5000 unique keys per agent

### Adjusting Limits

Edit `code/okome/budget.py` or pass limits as parameters:

```python
# More permissive
allowed, _ = allow_rate(agent_id, limit=120, window_seconds=60)

# More restrictive
allowed, _ = allow_rate(agent_id, limit=30, window_seconds=60)
```

### Monitoring Budgets

```bash
# Check rate limit keys
redis-cli -h 192.168.86.19 keys "okome:budget:rl:*"

# Check write budget keys
redis-cli -h 192.168.86.19 keys "okome:budget:writes:*"

# Check agent cardinality
redis-cli -h 192.168.86.19 keys "okome:agentkeys:*"
```

## Verification

### Test Canary Policies

```bash
# Control mode (default)
curl -I http://192.168.86.20/ui-schema/foo
# Check: X-OKOME-Canary: control

# Canary mode
curl -I -H "X-OKOME-Canary: canary" http://192.168.86.20/ui-schema/foo
# Check: X-OKOME-Canary: canary-ttl-5m

# Debug mode
curl -I -H "X-OKOME-Canary: debug" http://192.168.86.20/ui-schema/foo
# Check: X-OKOME-Canary: debug-bypass
```

### Test Pre-warming

```bash
# Check timer status
systemctl status okome-prewarm.timer

# Manually run pre-warm
sudo /usr/local/bin/okome-prewarm.sh

# Check cache after pre-warm
curl -I http://192.168.86.20/
# Should show X-Cache-Status: HIT
```

### Test Budget Enforcement

See Phase 3 documentation for budget testing.

## Troubleshooting

### Canary Not Working

1. Verify maps are included in Nginx config
2. Check Nginx config test: `sudo nginx -t`
3. Verify headers are being passed: `curl -v -H "X-OKOME-Canary: canary" ...`

### Pre-warm Not Running

1. Check timer: `systemctl status okome-prewarm.timer`
2. Check service logs: `journalctl -u okome-prewarm.service`
3. Verify log file exists and is readable
4. Test script manually: `sudo /usr/local/bin/okome-prewarm.sh`

## Next Steps

After completing Phase 4:
1. Test canary policies with different configurations
2. Monitor pre-warm effectiveness
3. Adjust budget limits as needed
4. Proceed to [Phase 5: Enterprise Hardening](05_ENTERPRISE_HARDENING.md)

---

**Last Updated**: 2026-01-24
