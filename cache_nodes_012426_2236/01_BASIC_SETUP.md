# Phase 1: Two-Node Basic Setup

**Goal**: Deploy basic two-node architecture (Nginx frontend + Redis backend)

**Nodes**:
- Frontend Cache: 192.168.86.20 (Nginx)
- Backend Cache: 192.168.86.19 (Redis)
- Upstream: 192.168.86.25:8000 (OKOME Orchestrator)

---

## Overview

This phase sets up the basic two-node cache infrastructure. The frontend node handles UI/static asset caching with Nginx, while the backend node provides Redis for planner/RAG caching.

## Architecture

```
Browser
   ↓
192.168.86.20 (Frontend Cache - Nginx)
   ↓
192.168.86.25:8000 (OKOME Orchestrator)
   ↓
192.168.86.19 (Backend Cache - Redis)
```

## Part A: Frontend Cache Node (192.168.86.20)

### Step 1: Install Nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### Step 2: Create Cache Directory

```bash
sudo mkdir -p /var/cache/nginx/okome
sudo chown -R www-data:www-data /var/cache/nginx
```

### Step 3: Install Nginx Configuration

Copy `configs/nginx-frontend/okome-frontend.conf` to `/etc/nginx/sites-available/okome-frontend`:

```bash
sudo cp cache_nodes_012426_2236/configs/nginx-frontend/okome-frontend.conf \
  /etc/nginx/sites-available/okome-frontend
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/okome-frontend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default  # Remove default site
```

### Step 4: Test and Reload

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Verify

```bash
curl -I http://192.168.86.20/
```

Expected headers:
- `X-OKOME-Node: frontend-cache`
- `X-Cache-Status: MISS` (first request)

## Part B: Backend Cache Node (192.168.86.19)

### Step 1: Install Redis

```bash
sudo apt update
sudo apt install -y redis-server
```

### Step 2: Configure Redis

Copy `configs/redis-backend/redis.conf` to `/etc/redis/redis.conf` (backup original first):

```bash
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
sudo cp cache_nodes_012426_2236/configs/redis-backend/redis.conf /etc/redis/redis.conf
```

### Step 3: Restart Redis

```bash
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

### Step 4: Verify

```bash
redis-cli -h 192.168.86.19 ping
```

Expected: `PONG`

## Configuration Details

### Frontend Cache (Nginx)

- **Cache Path**: `/var/cache/nginx/okome`
- **Cache Size**: 2GB max
- **Cache TTL**: 24h for static assets
- **Upstream**: 192.168.86.25:8000
- **Observability**: Headers added (X-Cache-Status, X-OKOME-Node)

### Backend Cache (Redis)

- **Memory**: 4GB max
- **Policy**: allkeys-lru
- **Persistence**: Disabled (appendonly no, save "")
- **Bind**: 127.0.0.1 and 192.168.86.19
- **Port**: 6379

## Cache Behavior

### Frontend Cache (Cached)

- `/assets/*` - JavaScript, CSS, images (24h TTL)
- `/ui-schema/*` - UI configuration (24h TTL)
- `/version` - Version info (5m TTL)
- `/health` - Health endpoint (30s TTL)

### Frontend Cache (Never Cached)

- `/api/*` - All API endpoints
- `/execute` - Execution requests
- `/agent` - Agent requests
- `/run` - Run requests
- `/ws` - WebSocket connections

### Backend Cache (Redis)

- Model metadata (24h TTL)
- Planner outputs (5-15 min TTL)
- RAG chunks (30-60 min TTL)
- Tool discovery (10 min TTL)

## Verification Script

Run the verification script:

```bash
./cache_nodes_012426_2236/scripts/verify.sh
```

This checks:
- Frontend node responds
- Backend Redis is accessible
- Cache headers are present
- Upstream connectivity

## Troubleshooting

### Frontend Node Issues

```bash
# Check Nginx status
sudo systemctl status nginx

# Check Nginx config
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log
```

### Backend Node Issues

```bash
# Check Redis status
sudo systemctl status redis-server

# Test Redis connection
redis-cli -h 192.168.86.19 ping

# Check Redis memory
redis-cli -h 192.168.86.19 info memory
```

## Next Steps

After completing Phase 1:
1. Verify both nodes are operational
2. Test cache behavior
3. Proceed to [Phase 2: Health-Gated Failover & Observability](02_FAILOVER_OBSERVABILITY.md)

---

**Last Updated**: 2026-01-24
