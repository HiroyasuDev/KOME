# Phase 3: Cache-Aware Planner & Rate Limiting

**Goal**: Integrate Redis cache with OKOME planner and add rate limiting

**Node**: Backend Cache (192.168.86.19 - Redis)  
**Integration**: OKOME Orchestrator (192.168.86.25:8000)

---

## Overview

This phase integrates Redis cache with the OKOME planner endpoint to short-circuit expensive planner computations. It includes stampede lock protection, budget enforcement, and comprehensive cache headers.

## Architecture

```
OKOME Planner Request
   ↓
Check Redis Cache (192.168.86.19)
   ↓
Cache HIT? → Return cached plan
   ↓
Cache MISS? → Acquire stampede lock
   ↓
Compute plan → Store in Redis → Return plan
```

## Cache Key Schema

```
okome:planner:{model}:{prompt_hash}:{toolset_version}:{repo_hash}
okome:model_meta:{model}
okome:rag:{repo}:{chunk_hash}
okome:tools:{tool_version}
okome:health:{node}
```

## TTL Standards

| Cache Type | TTL |
|------------|-----|
| Model metadata | 24h |
| Planner outputs | 5-15 min |
| RAG chunks | 30-60 min |
| Tool discovery | 10 min |
| Health | 30 sec |

## Part A: Cache Helper Module

### Installation

Copy `code/okome/cache.py` to your OKOME orchestrator codebase (or install as package).

### Usage

```python
from okome.cache import key_planner, get_json, set_json, with_lock, release_lock

# Generate cache key
cache_key = key_planner(
    model="gpt-4",
    prompt="Create a plan for...",
    toolset_version="v1.2.3",
    repo_hash="abc123"
)

# Check cache
cached = get_json(cache_key)
if cached:
    return cached

# Compute and cache
plan = compute_plan(...)
set_json(cache_key, plan, ttl_seconds=600)
```

## Part B: Budget Enforcement Module

### Installation

Copy `code/okome/budget.py` to your OKOME orchestrator codebase.

### Usage

```python
from okome.budget import allow_rate, allow_cache_write, record_agent_key

# Rate limit check
allowed, remaining = allow_rate(agent_id="agent-123", limit=60, window_seconds=60)
if not allowed:
    raise HTTPException(status_code=429, detail="Rate limit exceeded")

# Cache write budget
allowed_w, remaining_w = allow_cache_write(agent_id="agent-123", write_limit=30)
if allowed_w:
    set_json(cache_key, plan, ttl_seconds=600)
```

## Part C: Planner Integration

### Example Implementation

See `code/okome/planner_example.py` for a complete example of integrating cache and budget enforcement into a FastAPI planner endpoint.

### Key Features

1. **Cache Lookup**: Check Redis before computing
2. **Stampede Lock**: Prevent multiple simultaneous computations
3. **Budget Enforcement**: Rate limits and write budgets per agent
4. **Response Headers**: X-OKOME-Cache, X-OKOME-Cache-Key
5. **Unity Safety**: Include repo_hash in cache key

## Part D: Enhanced Rate Limiting

The hardened Nginx config (Phase 2) already includes enhanced rate limiting:

- **UI endpoints**: 20 req/s, burst 60
- **API endpoints**: 5 req/s, burst 10
- **Connection limits**: 30 per IP

## Verification

### Test Cache Integration

```python
# From OKOME orchestrator
import requests

response = requests.post(
    "http://192.168.86.25:8000/api/planner",
    json={"model": "gpt-4", "prompt": "test"},
    headers={"X-OKOME-Agent": "test-agent", "X-Repo-Hash": "abc123"}
)

# Check headers
print(response.headers.get("X-OKOME-Cache"))  # Should be MISS first time
print(response.headers.get("X-OKOME-Cache-Key"))

# Second request should be HIT
response2 = requests.post(...)
print(response2.headers.get("X-OKOME-Cache"))  # Should be HIT
```

### Test Budget Enforcement

```python
# Make 61 requests in 60 seconds
for i in range(61):
    response = requests.post(...)
    if response.status_code == 429:
        print(f"Rate limited at request {i+1}")
        break
```

### Check Redis Keys

```bash
redis-cli -h 192.168.86.19 keys "okome:planner:*"
redis-cli -h 192.168.86.19 keys "okome:budget:*"
```

## Hard Rules

### DO NOT Cache

- File writes
- Git operations
- Unity builds
- Agent memory
- Tool execution results

### Cache ONLY

- Read-only data
- Deterministic computations
- Recomputable results

## Troubleshooting

### Cache Not Working

1. Verify Redis connectivity: `redis-cli -h 192.168.86.19 ping`
2. Check cache keys: `redis-cli -h 192.168.86.19 keys "okome:*"`
3. Verify TTLs: `redis-cli -h 192.168.86.19 ttl <key>`

### Budget Enforcement Issues

1. Check budget keys: `redis-cli -h 192.168.86.19 keys "okome:budget:*"`
2. Verify agent ID is being passed in headers
3. Check response headers for `X-OKOME-Agent-Rate-Remaining`

### Stampede Lock Issues

1. Check lock keys: `redis-cli -h 192.168.86.19 keys "*:lock"`
2. Verify lock TTL (should be 8-10 seconds)
3. Check for stuck locks (TTL = -1)

## Next Steps

After completing Phase 3:
1. Integrate cache.py and budget.py into OKOME orchestrator
2. Update planner endpoint
3. Test cache hit/miss behavior
4. Monitor budget enforcement
5. Proceed to [Phase 4: Advanced Features](04_ADVANCED_FEATURES.md)

---

**Last Updated**: 2026-01-24
