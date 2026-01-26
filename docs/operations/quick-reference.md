# OKOME Cache Node — Quick Reference

## One-Line Deployment

```bash
./scripts/deploy-cache-node.sh
```

## Network Topology

```
Browser → 192.168.86.20 (Cache Pi) → 192.168.86.25:3000 (OptiPlex Open WebUI)
```

## Cache Configuration

| Setting | Value |
|---------|-------|
| **Cache Size** | 1 GB (hard cap) |
| **Cache TTL** | 24 hours |
| **Cached Paths** | `/assets/*`, `/ui-schema/*`, `/version/*` |
| **Never Cached** | `/v1/*`, `/infer`, `/stream`, WebSockets, Auth |

## Verification

```bash
# Test cache node
curl -I http://192.168.86.20/assets/app.js

# Expected headers:
# X-Cache: HIT (after first request)
# X-Cache: MISS (first request)
```

## Common Commands

```bash
# SSH to cache node (port 22)
sshpass -p "usshopper" ssh -p 22 ncadmin@192.168.86.20

# Check NGINX status
sudo systemctl status nginx

# View logs
sudo tail -f /var/log/nginx/access.log

# Clear cache
sudo rm -rf /var/cache/nginx/static/* && sudo systemctl reload nginx
```

## Failure Recovery

**Cache node dies**: Browser hits OptiPlex directly (no config change needed)

**Rebuild time**: < 15 minutes

**Rebuild steps**:
1. Reimage SD card
2. Configure static IP: 192.168.86.20
3. Run: `./scripts/deploy-cache-node.sh`

## Full Documentation

See: `docs/operations/cache-node-runbook.md`
