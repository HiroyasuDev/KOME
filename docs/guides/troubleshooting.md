# KOME Troubleshooting Guide

## Common Issues

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
- Check network cable/connection

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
- Verify OKOME core is running on OptiPlex
- Check network connectivity: `ping 192.168.86.25`
- Verify Open WebUI is accessible on OptiPlex
- Check firewall rules between cache node and OptiPlex

### Cache Not Working

**Symptoms**: All requests show `X-Cache: MISS` or no cache headers

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
- Check NGINX configuration: `sudo nginx -t`

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
- Clear old logs if needed: `sudo logrotate -f /etc/logrotate.d/nginx-kome`

### Slow Performance

**Symptoms**: Cache node is slow

**Diagnosis**:
```bash
# Check cache hit rate
./scripts/stats.sh

# Check system resources
top
free -h
df -h
```

**Resolution**:
- Verify cache is being used (check hit rate)
- Check if upstream (OptiPlex) is slow
- Verify network connectivity
- Check for SD card wear (if not using tmpfs)

### NGINX Configuration Errors

**Symptoms**: `nginx -t` fails

**Diagnosis**:
```bash
sudo nginx -t
```

**Resolution**:
- Review error message
- Check syntax in `/etc/nginx/conf.d/kome-cache.conf`
- Verify upstream IP/port is correct
- Check for typos in configuration

## Diagnostic Commands

### System Health

```bash
# System uptime and load
uptime

# Memory usage
free -h

# Disk usage
df -h

# NGINX status
sudo systemctl status nginx
```

### Cache Status

```bash
# Cache statistics
./scripts/stats.sh

# Cache directory size
sudo du -sh /var/cache/nginx/static

# Recent cache hits/misses
sudo tail -100 /var/log/nginx/access.log | grep X-Cache
```

### Network Diagnostics

```bash
# Test upstream
curl -v http://192.168.86.25:3000

# Test cache node
curl -v http://192.168.86.20

# Network connectivity
ping 192.168.86.25
ping 192.168.86.1
```

### Log Analysis

```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u nginx -f
```

## Recovery Procedures

### Rebuild Cache Node

If the cache node fails completely:

1. **Reimage SD card** with Raspberry Pi OS Lite
2. **Configure static IP**: 192.168.86.20
3. **Run bootstrap script**: `sudo ./scripts/bootstrap.sh`
4. **Verify**: `./scripts/test.sh`

**Target rebuild time**: < 15 minutes

### Clear Cache

```bash
./scripts/purge.sh
```

### Restart NGINX

```bash
sudo systemctl restart nginx
```

### Reload Configuration

```bash
sudo nginx -t && sudo systemctl reload nginx
```

## Getting Help

1. Check this troubleshooting guide
2. Review operations runbook: `docs/operations/runbook.md`
3. Check NGINX logs: `/var/log/nginx/error.log`
4. Verify upstream: `curl http://192.168.86.25:3000`
