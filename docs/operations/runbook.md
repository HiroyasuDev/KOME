# OKOME Frontend Cache Node — Operations Runbook

**Node**: CN00 (192.168.86.20)  
**Role**: Lightweight edge cache for frontend assets  
**OS**: Raspberry Pi OS Lite (64-bit)  
**Storage**: microSD only (16GB minimum, 32GB recommended)

---

## Quick Reference

| Item | Value |
|------|-------|
| **IP Address** | 192.168.86.20 |
| **SSH Port** | 22 (Standard SSH port) |
| **SSH User** | ncadmin |
| **SSH Password** | usshopper |
| **Upstream** | 192.168.86.25:3000 (OptiPlex Open WebUI) |
| **Cache Size** | 1 GB (hard cap) |
| **Cache TTL** | 24 hours |

---

## Initial Deployment

### Prerequisites

- Raspberry Pi 3 or newer
- 16GB+ microSD card (Class 10 / A1 minimum)
- Raspberry Pi OS Lite installed
- Static IP configured: 192.168.86.20
- SSH access enabled

### One-Command Bootstrap

From your local machine (with SSH access):

```bash
cd /Users/hiroyasu/Documents/GitHub/KOME
./scripts/deploy.sh
```

Or manually:

```bash
cd /Users/hiroyasu/Documents/GitHub/KOME
sshpass -p "usshopper" \
  ssh -p 22 -o StrictHostKeyChecking=no ncadmin@192.168.86.20 \
  "sudo bash -s" < scripts/bootstrap.sh
```

Or manually on the Pi:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/.../cache-node-bootstrap.sh)
```

### Post-Deployment Verification

```bash
# 1. Test NGINX configuration
sudo nginx -t

# 2. Test upstream connectivity
curl -I http://192.168.86.25:3000

# 3. Test cache node
curl -I http://192.168.86.20/assets/app.js

# Expected: X-Cache: MISS (first request)
# Then: X-Cache: HIT (subsequent requests)
```

---

## Daily Operations

### Check Cache Status

```bash
# View access logs
sudo tail -f /var/log/nginx/access.log

# Check cache hit ratio
sudo tail -1000 /var/log/nginx/access.log | grep "X-Cache" | sort | uniq -c

# Check disk usage
df -h /var/cache/nginx
```

### Monitor Cache Performance

```bash
# Watch real-time cache hits/misses
sudo tail -f /var/log/nginx/access.log | grep --line-buffered "X-Cache"

# Count cache statistics
sudo grep "X-Cache" /var/log/nginx/access.log | \
  awk '{print $NF}' | sort | uniq -c
```

### Clear Cache (if needed)

```bash
# Clear entire cache
sudo rm -rf /var/cache/nginx/static/*

# Reload NGINX
sudo systemctl reload nginx
```

---

## Troubleshooting

### Cache Node Unreachable

**Symptoms**: Browser can't connect to 192.168.86.20

**Diagnosis**:
```bash
# From local machine
ping 192.168.86.20
curl -I http://192.168.86.20

# On cache node
sudo systemctl status nginx
sudo nginx -t
```

**Resolution**:
- Check NGINX is running: `sudo systemctl start nginx`
- Check firewall: `sudo ufw status`
- Verify static IP configuration

### Upstream Connection Failed

**Symptoms**: `502 Bad Gateway` errors

**Diagnosis**:
```bash
# Test upstream directly
curl -I http://192.168.86.25:3000

# Check NGINX error logs
sudo tail -50 /var/log/nginx/error.log
```

**Resolution**:
- Verify OptiPlex is running: `ssh llmadmin@192.168.86.25 "systemctl status docker"`
- Check network connectivity: `ping 192.168.86.25`
- Verify Open WebUI is accessible on OptiPlex

### Cache Not Working

**Symptoms**: All requests show `X-Cache: MISS` or `X-Cache: BYPASS`

**Diagnosis**:
```bash
# Check cache directory
ls -lh /var/cache/nginx/static/

# Check permissions
sudo ls -ld /var/cache/nginx/static/

# Verify cache zone
sudo nginx -T | grep -A 10 "proxy_cache_path"
```

**Resolution**:
- Ensure cache directory exists: `sudo mkdir -p /var/cache/nginx/static`
- Fix permissions: `sudo chown -R www-data:www-data /var/cache/nginx`
- Verify URL matches cache allowlist: `/assets/`, `/ui-schema/`, `/version/`

### High Disk Usage

**Symptoms**: SD card filling up

**Diagnosis**:
```bash
# Check disk usage
df -h
du -sh /var/cache/nginx/static
du -sh /var/log/nginx
```

**Resolution**:
- Cache is hard-capped at 1GB (configured in NGINX)
- Logs rotate daily (7 days retention)
- If tmpfs is used, cache clears on reboot (by design)

---

## Maintenance

### Update NGINX Configuration

```bash
# Edit configuration
sudo nano /etc/nginx/conf.d/kome-cache.conf

# Test configuration
sudo nginx -t

# Reload (zero downtime)
sudo systemctl reload nginx
```

### System Updates

```bash
# Update system (minimal writes)
sudo apt update
sudo apt full-upgrade -y

# Restart NGINX if needed
sudo systemctl restart nginx
```

### Rebuild Cache Node

If the cache node fails completely:

1. **Reimage SD card** with Raspberry Pi OS Lite
2. **Configure static IP**: 192.168.86.20
3. **Run bootstrap script** (see Initial Deployment)
4. **Verify** (see Post-Deployment Verification)

**Target rebuild time**: < 15 minutes

---

## Failure Scenarios

### Cache Node Dies

**Impact**: Minimal — browser hits OptiPlex directly

**Recovery**:
- No action required (passive failover)
- Rebuild when convenient (see Rebuild Cache Node)

### OptiPlex Dies

**Impact**: Cache serves stale assets (24h TTL), but API calls fail

**Recovery**:
- Fix OptiPlex
- Cache automatically refreshes on next request

### Network Partition

**Impact**: Cache node can't reach OptiPlex

**Symptoms**: `502 Bad Gateway` errors

**Recovery**:
- Check network connectivity
- Verify router configuration
- Check firewall rules

---

## Performance Metrics

### Expected Cache Hit Ratio

- **Target**: > 80% for static assets
- **Measurement**: `X-Cache: HIT` vs `X-Cache: MISS`

### Latency Improvement

- **Cached requests**: < 10ms (local)
- **Uncached requests**: ~50-100ms (upstream)
- **API requests**: No change (always upstream)

### Resource Usage

- **CPU**: < 5% (idle)
- **RAM**: ~50-100 MB (NGINX)
- **Disk**: < 5 GB total (OS + cache + logs)

---

## Security Notes

- **No TLS internally**: LAN-only, no secrets
- **No authentication**: Cache node is transparent proxy
- **Rate limiting**: 10 req/s per IP (burst: 20)
- **Firewall**: Only port 80 open (HTTP)

---

## What NOT to Add

❌ Redis / Memcached  
❌ Kubernetes  
❌ TLS certificates  
❌ Active health checks  
❌ Lua / JavaScript in NGINX  
❌ Cloudflare on this node  
❌ Model storage  
❌ Secrets / credentials  

**Keep it boring and disposable.**

---

## Support

For issues:
1. Check this runbook
2. Review NGINX logs: `/var/log/nginx/error.log`
3. Verify upstream: `curl http://192.168.86.25:3000`
4. Rebuild if needed (15 min target)

---

**Last Updated**: 2026-01-22  
**Version**: 1.0
