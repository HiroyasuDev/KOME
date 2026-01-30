# Phase 2: Health-Gated Failover & Observability

**Goal**: Add active health checks, failover logic, and comprehensive observability

**Node**: Frontend Cache (192.168.86.20)

---

## Overview

This phase adds health-gated failover logic that allows the frontend cache to serve stale content when the upstream orchestrator is unhealthy, plus comprehensive observability headers and logging.

## Architecture

```
Health Probe (systemd timer, every 5s)
   ↓
Checks http://192.168.86.25:8000/health
   ↓
Writes /etc/nginx/okome/health_state.conf
   ↓
Nginx includes health_state.conf
   ↓
Serves stale cache if upstream unhealthy
```

## Part A: Health Probe Setup

### Step 1: Create Health Probe Script

The script `scripts/okome-health-probe.sh` checks upstream health and writes a state file that Nginx includes.

### Step 2: Create Systemd Service

Copy `configs/systemd/okome-health-probe.service` to `/etc/systemd/system/`

### Step 3: Create Systemd Timer

Copy `configs/systemd/okome-health-probe.timer` to `/etc/systemd/system/`

### Step 4: Enable Timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now okome-health-probe.timer
```

### Step 5: Verify

```bash
systemctl status okome-health-probe.timer
cat /etc/nginx/okome/health_state.conf
```

## Part B: Enhanced Nginx Configuration

### Step 1: Create Health State Directory

```bash
sudo mkdir -p /etc/nginx/okome /var/www/okome
echo "OKOME temporarily unavailable" | sudo tee /var/www/okome/maintenance.txt >/dev/null
```

### Step 2: Create Initial Health State

```bash
echo "set \$okome_upstream_ok 1;" | sudo tee /etc/nginx/okome/health_state.conf >/dev/null
```

### Step 3: Install Hardened Nginx Config

Copy `configs/nginx-frontend/okome-frontend-hardened.conf` to `/etc/nginx/sites-available/okome-frontend` (backup original first).

### Step 4: Test and Reload

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Features

### Health-Gated Failover

- Active health probe checks upstream every 5 seconds
- If upstream unhealthy → serve stale cache (if available)
- If no stale cache → serve maintenance page (503)
- Automatic recovery when upstream becomes healthy

### Observability Headers

All responses include:
- `X-OKOME-Node: frontend-cache`
- `X-Cache-Status: HIT|MISS|BYPASS|EXPIRED|UPDATING`
- `X-Upstream: 192.168.86.25:8000`
- `X-Upstream-Status: 200|502|503|504`
- `X-Request-ID: <unique-id>`

### Enhanced Logging

Custom log format includes:
- Cache status
- Upstream address
- Response times
- Request ID

## Verification

### Test Health Probe

```bash
# Check timer status
systemctl status okome-health-probe.timer

# Manually run probe
sudo /usr/local/bin/okome-health-probe.sh

# Check state file
cat /etc/nginx/okome/health_state.conf
```

### Test Stale Cache Serving

1. Stop upstream orchestrator temporarily
2. Wait for health probe to detect (5 seconds)
3. Request cached asset: `curl -I http://192.168.86.20/assets/app.js`
4. Should return cached content with `X-Cache-Status: HIT` or `UPDATING`

### Test Observability

```bash
curl -I http://192.168.86.20/
```

Check for headers:
- `X-OKOME-Node`
- `X-Cache-Status`
- `X-Upstream`
- `X-Request-ID`

## Hit Ratio Calculation

Use the script to calculate cache hit ratios:

```bash
./scripts/calculate-hit-ratio.sh
```

This analyzes Nginx access logs and reports:
- Total requests
- Cache hits
- Cache misses
- Hit ratio percentage

## Nginx Status Page

Access the status page (LAN only):

```bash
curl http://192.168.86.20/nginx_status
```

Shows:
- Active connections
- Requests per second
- Connections accepted/handled

## Troubleshooting

### Health Probe Not Running

```bash
# Check timer
systemctl status okome-health-probe.timer

# Check service
systemctl status okome-health-probe.service

# View logs
journalctl -u okome-health-probe.service
```

### Stale Cache Not Serving

1. Verify health state file exists: `cat /etc/nginx/okome/health_state.conf`
2. Check Nginx includes it: `grep health_state.conf /etc/nginx/sites-available/okome-frontend`
3. Verify cache has content: `ls -lh /var/cache/nginx/okome/`

### Observability Headers Missing

1. Check Nginx config includes header directives
2. Verify Nginx reloaded: `systemctl status nginx`
3. Check for errors: `sudo tail -f /var/log/nginx/error.log`

## Next Steps

After completing Phase 2:
1. Verify health probe is running
2. Test stale cache serving
3. Monitor hit ratios
4. Proceed to [Phase 3: Cache-Aware Planner & Rate Limiting](03_CACHE_PLANNER.md)

---

**Last Updated**: 2026-01-24
