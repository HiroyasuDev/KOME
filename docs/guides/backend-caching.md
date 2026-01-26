# Backend Caching Guide (Advanced)

## Overview

> **⚠️ Advanced Feature**: CN00 is designed for **frontend-only caching**. Backend API caching is available but not recommended for the primary cache node. Use this guide only if you have specific requirements for backend caching.

KOME can cache both **frontend assets** (static files) and **backend API responses** (dynamic data). This guide explains how to configure backend caching and the trade-offs involved.

## Frontend vs Backend Caching

### Frontend Caching (Current)
- **What**: Static assets (JS, CSS, images)
- **TTL**: 24 hours (assets rarely change)
- **Key**: URL path only
- **Risk**: Low (serving stale assets is usually safe)

### Backend Caching (Optional)
- **What**: API responses (GET requests, model lists, configs)
- **TTL**: Minutes to hours (depends on data volatility)
- **Key**: URL + headers (Auth, User-ID, etc.)
- **Risk**: Medium (serving stale data can cause issues)

## When to Cache Backend Responses

### ✅ Good Candidates for Backend Caching

1. **Read-only endpoints**:
   - Model lists (`/v1/models`)
   - System configuration (`/v1/config`)
   - Version information
   - Public data

2. **Expensive computations**:
   - Aggregated statistics
   - Search results (with short TTL)
   - Reports

3. **Frequently accessed, rarely changing data**:
   - User profiles (with user-specific cache keys)
   - Settings (with invalidation on update)

### ❌ Never Cache

1. **State-changing operations**:
   - POST, PUT, DELETE, PATCH requests
   - Authentication endpoints (`/auth/*`)
   - WebSocket connections
   - Server-Sent Events (SSE)

2. **User-specific dynamic data**:
   - Chat messages
   - Real-time inference (`/infer`, `/stream`)
   - Session data

3. **Time-sensitive data**:
   - Live metrics
   - Real-time status

## Configuration Options

### Option 1: Separate Cache Zone (Recommended)

Create a dedicated cache zone for backend responses with different TTL:

```nginx
# Frontend cache (existing)
proxy_cache_path /var/cache/nginx/static
    levels=1:2
    keys_zone=STATIC:50m
    inactive=24h
    max_size=1g
    use_temp_path=off;

# Backend cache (new)
proxy_cache_path /var/cache/nginx/api
    levels=1:2
    keys_zone=API:100m
    inactive=1h
    max_size=500m
    use_temp_path=off;
```

### Option 2: Cache Specific Endpoints

Cache only safe, read-only endpoints:

```nginx
# Cache model list (changes rarely)
location ~ ^/v1/models$ {
    proxy_pass http://kome_core;
    proxy_cache API;
    proxy_cache_valid 200 5m;  # 5 minute TTL
    proxy_cache_key "$scheme$request_method$host$request_uri";
    add_header X-Cache $upstream_cache_status;
    
    # Don't cache if auth header present (user-specific)
    proxy_cache_bypass $http_authorization;
    proxy_no_cache $http_authorization;
    
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

# Cache config endpoint
location ~ ^/v1/config$ {
    proxy_pass http://kome_core;
    proxy_cache API;
    proxy_cache_valid 200 15m;  # 15 minute TTL
    proxy_cache_key "$scheme$request_method$host$request_uri";
    add_header X-Cache $upstream_cache_status;
    
    proxy_http_version 1.1;
    proxy_set_header Host $host;
}
```

### Option 3: Cache All GET Requests (Aggressive)

Cache all GET requests with short TTL:

```nginx
# Cache all GET requests to /v1/* (except excluded paths)
location ~ ^/v1/(?!auth|infer|stream) {
    # Only cache GET requests
    set $cache_method $request_method;
    if ($request_method != GET) {
        set $cache_method "NO_CACHE";
    }
    
    proxy_pass http://kome_core;
    proxy_cache API;
    proxy_cache_valid 200 2m;  # 2 minute TTL
    proxy_cache_key "$scheme$request_method$host$request_uri$http_authorization";
    
    # Bypass cache for authenticated requests (optional)
    proxy_cache_bypass $http_authorization;
    proxy_no_cache $http_authorization;
    
    add_header X-Cache $upstream_cache_status;
    
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Cache Key Considerations

### User-Specific Data

If caching user-specific responses, include auth/user headers in cache key:

```nginx
proxy_cache_key "$scheme$request_method$host$request_uri$http_authorization";
```

### Query Parameters

Include query params if they affect response:

```nginx
proxy_cache_key "$scheme$request_method$host$request_uri$args";
```

## Cache Invalidation

### Manual Purge

Use the purge script to clear backend cache:

```bash
# Purge specific path
sshpass -p "usshopper" ssh ncadmin@192.168.86.20 \
  "sudo rm -rf /var/cache/nginx/api/*"

# Or use the purge script
./scripts/purge.sh
```

### TTL-Based Expiration

Set appropriate TTLs based on data volatility:
- **Model lists**: 5-15 minutes
- **Config**: 15-60 minutes
- **Public data**: 1-24 hours

### Cache-Control Headers

Respect upstream `Cache-Control` headers:

```nginx
proxy_cache_valid 200 2m;
proxy_ignore_headers "Set-Cookie";
proxy_hide_header "Set-Cookie";
```

## Monitoring Backend Cache

### Check Cache Hit Rate

```bash
# View cache statistics
./scripts/stats.sh

# Check specific endpoint cache hits
sshpass -p "usshopper" ssh ncadmin@192.168.86.20 \
  "sudo tail -100 /var/log/nginx/access.log | grep '/v1/models' | grep 'X-Cache.*HIT'"
```

### Cache Size Monitoring

```bash
sshpass -p "usshopper" ssh ncadmin@192.168.86.20 \
  "sudo du -sh /var/cache/nginx/api"
```

## Trade-offs

### ✅ Benefits

- **Reduced load on OKOME core**: Fewer requests to OptiPlex
- **Faster responses**: Sub-10ms for cached API responses
- **Better performance**: Especially for frequently accessed endpoints

### ⚠️ Risks

- **Stale data**: Users may see outdated information
- **Cache invalidation complexity**: Need to purge when data changes
- **Memory usage**: Backend cache can grow faster than frontend cache
- **Debugging complexity**: Harder to troubleshoot when cache is involved

## Recommended Approach

### Conservative (Recommended for Start)

1. **Start with read-only endpoints only**:
   - `/v1/models` (5-15 min TTL)
   - `/v1/config` (15-60 min TTL)
   - `/version` (already cached)

2. **Monitor cache hit rates**:
   - Target > 50% hit rate for cached endpoints
   - Watch for stale data complaints

3. **Gradually expand**:
   - Add more endpoints as confidence grows
   - Adjust TTLs based on data volatility

### Aggressive (Advanced)

1. **Cache all GET requests** with short TTL (1-2 minutes)
2. **Implement cache invalidation** on data updates
3. **Monitor closely** for stale data issues

## Example: Full Configuration

See `infra/cache/nginx-kome-cache-backend.conf` for a complete example with both frontend and backend caching enabled.

---

## CN00 Recommendation

**For CN00 (Primary Cache Node)**: Use **frontend-only caching** (default configuration). This keeps the cache node simple, predictable, and easy to maintain.

**Backend caching should only be considered**:
- For a separate cache node (not CN00)
- If you have specific, well-understood endpoints that would benefit
- If you can implement proper cache invalidation
- If you can monitor for stale data issues

**Default CN00 configuration**: Frontend-only (`infra/cache/nginx-kome-cache.conf`)  
**Advanced configuration**: Frontend + Backend (`infra/cache/nginx-kome-cache-backend.conf`)
