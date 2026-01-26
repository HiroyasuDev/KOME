# OKOME Two-Node – Production Ready

Both cache nodes are configured and validated.

## Access

| Node | IP | Host | User | SSH | Password |
|------|----|------|------|-----|----------|
| **CN00** (Frontend) | 192.168.86.20 | Cache Node | ncadmin | `ssh -p 22 ncadmin@192.168.86.20` | usshopper |
| **CN01** (Backend) | 192.168.86.19 | Cache Node | ncadmin | `ssh -p 22 ncadmin@192.168.86.19` | ussfitzgerald |

## Verification (no passwordless SSH)

```bash
cd /Users/hiroyasu/Documents/GitHub/KOME

# One-command validation (both nodes)
./cache_nodes_012426_2236/scripts/okome-validate.sh

# Frontend only
./cache_nodes_012426_2236/scripts/verify_frontend.sh 192.168.86.20

# Backend only
./cache_nodes_012426_2236/scripts/verify_backend.sh 192.168.86.19

# Connectivity (Nginx + Redis)
./cache_nodes_012426_2236/scripts/verify.sh 192.168.86.20 192.168.86.19
```

## Manual SSH checks

```bash
# CN00
sshpass -p "usshopper" ssh -p 22 -o StrictHostKeyChecking=no ncadmin@192.168.86.20 \
  "echo 'SSH OK' && hostname && whoami"

# CN01
sshpass -p "ussfitzgerald" ssh -p 22 -o StrictHostKeyChecking=no ncadmin@192.168.86.19 \
  "echo 'SSH OK' && hostname && whoami"
```

## Deploy / Reconfig

```bash
# Frontend (CN00) – Nginx, okome-frontend.conf, usshopper
OKOME_FRONTEND_PASS=usshopper ./cache_nodes_012426_2236/scripts/deploy_frontend_production.sh 192.168.86.20

# Backend (CN01) – Redis, static IP, hardening, ussfitzgerald
OKOME_BACKEND_PASS=ussfitzgerald ./cache_nodes_012426_2236/scripts/deploy_backend_production.sh 192.168.86.19
```

## Architecture

```
Browser → 192.168.86.20 (Nginx) → 192.168.86.25:8000 (Orchestrator) → 192.168.86.19 (Redis) → GPU
```

- **Frontend**: `/var/cache/nginx/okome` (2GB), upstream 192.168.86.25:8000, X-Cache-Status, X-OKOME-Node.
- **Backend**: Redis 127.0.0.1:6379 + 192.168.86.19:6379, 4GB maxmemory, allkeys-lru, no persistence.

## Next steps

1. **Start orchestrator** at 192.168.86.25:8000 to clear Nginx 504.
2. **Point orchestrator** at Redis: `192.168.86.19:6379`.
3. **Use frontend** in browser: `http://192.168.86.20`.

---

**Status**: Both nodes complete and ready. Run `./cache_nodes_012426_2236/scripts/okome-validate.sh` to confirm.
