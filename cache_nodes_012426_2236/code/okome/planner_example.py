"""
OKOME Planner Endpoint Example
Demonstrates cache-aware planner with stampede locks and budget enforcement
"""

from fastapi import APIRouter, Header, HTTPException, Response
from typing import Optional
import time

from okome.cache import (
    key_planner,
    get_json,
    set_json,
    with_lock,
    release_lock,
    TTL_PLANNER
)
from okome.budget import (
    allow_rate,
    allow_cache_write,
    record_agent_key,
    DEFAULT_RATE_LIMIT,
    DEFAULT_WRITE_LIMIT
)

router = APIRouter()


@router.post("/api/planner")
def planner(
    payload: dict,
    response: Response,
    x_okome_agent: str = Header(default="anon"),
    x_repo_hash: str = Header(default="unknown")
):
    """
    Planner endpoint with cache short-circuiting and budget enforcement.
    
    Headers:
        X-OKOME-Agent: Agent identifier (for budget tracking)
        X-Repo-Hash: Repository state hash (for Unity safety)
    """
    model = payload.get("model", "default")
    prompt = payload.get("prompt", "")
    toolset_version = payload.get("toolset_version", "v1")
    repo_hash = x_repo_hash

    # 1) Rate limit check
    allowed, remaining = allow_rate(x_okome_agent, limit=DEFAULT_RATE_LIMIT, window_seconds=60)
    response.headers["X-OKOME-Agent-Rate-Remaining"] = str(remaining)
    if not allowed:
        raise HTTPException(status_code=429, detail="Agent rate limit exceeded")

    # 2) Generate cache key
    cache_key = key_planner(model, prompt, toolset_version, repo_hash)

    # 3) Check cache
    cached = None
    try:
        cached = get_json(cache_key)
    except Exception:
        cached = None

    if cached is not None:
        response.headers["X-OKOME-Cache"] = "HIT"
        response.headers["X-OKOME-Cache-Key"] = cache_key
        return cached

    # 4) Stampede lock
    lock_key = f"{cache_key}:lock"
    got_lock = False
    try:
        got_lock = with_lock(lock_key, ttl_seconds=8)
    except Exception:
        got_lock = False

    if not got_lock:
        # Another request is computing. Wait for value to appear.
        for _ in range(6):
            time.sleep(0.15)
            try:
                cached = get_json(cache_key)
            except Exception:
                cached = None
            if cached is not None:
                response.headers["X-OKOME-Cache"] = "HIT-WAIT"
                response.headers["X-OKOME-Cache-Key"] = cache_key
                return cached

    # 5) Compute plan (your existing logic here)
    # This is where you'd call your actual planner
    plan = {
        "model": model,
        "plan": ["step1", "step2", "step3"],  # Replace with actual plan
        "timestamp": time.time(),
    }

    # 6) Check cache write budget before storing
    allowed_w, remaining_w = allow_cache_write(x_okome_agent, write_limit=DEFAULT_WRITE_LIMIT, window_seconds=60)
    response.headers["X-OKOME-Agent-Write-Remaining"] = str(remaining_w)

    if allowed_w:
        # Record cardinality to prevent unique-key storms
        within_cap = record_agent_key(x_okome_agent, cache_key, max_keys=5000)
        if within_cap:
            try:
                set_json(cache_key, plan, ttl_seconds=TTL_PLANNER)
            except Exception:
                pass
        else:
            response.headers["X-OKOME-Cache-Write"] = "SKIP-CARDINALITY-CAP"
    else:
        response.headers["X-OKOME-Cache-Write"] = "SKIP-BUDGET"

    # 7) Release lock
    if got_lock:
        release_lock(lock_key)

    response.headers["X-OKOME-Cache"] = "MISS"
    response.headers["X-OKOME-Cache-Key"] = cache_key
    return plan
