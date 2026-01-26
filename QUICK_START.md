# KOME Quick Start Guide

Get KOME cache node up and running in minutes.

## Prerequisites

- Raspberry Pi 3+ with Raspberry Pi OS Lite
- Static IP: 192.168.86.20
- SSH access enabled
- OKOME core running at 192.168.86.25:3000

## 5-Minute Setup

### 1. Clone Repository

```bash
git clone https://github.com/HiroyasuDev/KOME.git
cd KOME
```

### 2. Verify Connectivity

```bash
./scripts/verify-connectivity.sh
```

### 3. Deploy

```bash
./scripts/deploy.sh
```

### 4. Test

```bash
./scripts/test.sh
```

## Using Make Commands

```bash
make deploy    # Deploy cache node
make test      # Test functionality
make stats     # View statistics
make purge     # Clear cache
make verify    # Verify connectivity
```

## Point Browser to Cache Node

**Before**: `http://192.168.86.25:3000`  
**After**: `http://192.168.86.20`

## Verify Cache is Working

1. Open browser dev tools (F12)
2. Navigate to `http://192.168.86.20`
3. Check Network tab
4. Look for `X-Cache: HIT` on second page load

## Common Commands

```bash
# View cache statistics
./scripts/stats.sh

# Monitor logs
sshpass -p "usshopper" ssh -p 22 ncadmin@192.168.86.20 \
  "sudo tail -f /var/log/nginx/access.log"

# Purge cache
./scripts/purge.sh
```

## Next Steps

- Read full documentation: `docs/operations/runbook.md`
- Configure clients: `docs/guides/client-config.md`
- Troubleshooting: `docs/guides/troubleshooting.md`

---

**That's it!** Your cache node is ready to accelerate frontend assets. 🚀
