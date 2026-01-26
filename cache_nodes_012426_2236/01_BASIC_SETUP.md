# Phase 1: Two-Node Basic Setup

Goal: Frontend (Nginx) + Backend (Redis) in production.

## Backend (192.168.86.19)

1. **Static IP**  
   NetworkManager or dhcpcd → 192.168.86.19/24.

2. **Deploy & run**  
   ```bash
   ./scripts/deploy_backend_production.sh 192.168.86.19
   ```  
   Installs Redis, applies `configs/redis-backend/redis.conf`, journald, sysctl, logrotate.

3. **Verify**  
   ```bash
   ./scripts/verify_backend.sh 192.168.86.19
   redis-cli -h 192.168.86.19 ping
   ```

## Frontend (192.168.86.20)

1. **Static IP**  
   192.168.86.20/24 (NetworkManager or dhcpcd).

2. **Deploy & run**  
   ```bash
   ./scripts/deploy_frontend_production.sh 192.168.86.20
   ```  
   Installs Nginx, deploys `configs/nginx-frontend/okome-frontend.conf`, cache dir `/var/cache/nginx/okome` (2GB), logrotate.

3. **Verify**  
   ```bash
   curl -I http://192.168.86.20/
   curl -I http://192.168.86.20/assets/
   ```  
   Check `X-Cache-Status` and `X-OKOME-Node`.

## Upstream

- Frontend upstream: **192.168.86.25:8000** (OKOME Orchestrator).  
- Orchestrator uses **192.168.86.19:6379** for Redis (configure in orchestrator app).

## Two-Node Verify

```bash
./scripts/okome-validate.sh
./scripts/verify.sh 192.168.86.20 192.168.86.19
```

## Access (no passwordless SSH)

- **CN00** (192.168.86.20): `sshpass -p 'usshopper' ssh ncadmin@192.168.86.20`
- **CN01** (192.168.86.19): `sshpass -p 'ussfitzgerald' ssh ncadmin@192.168.86.19`

See [READY.md](READY.md) for full checklist.

## Configs

- `configs/nginx-frontend/okome-frontend.conf`  
- `configs/redis-backend/redis.conf`  
- `configs/sysctl-okome.conf`, `configs/journald-okome.conf`
