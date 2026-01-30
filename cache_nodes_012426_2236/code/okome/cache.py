"""
OKOME Cache Helper Module
Redis cache integration for planner, RAG, and metadata caching
"""

import hashlib
import json
import os
import time
from typing import Any, Optional

import redis

REDIS_HOST = os.getenv("OKOME_REDIS_HOST", "192.168.86.19")
REDIS_PORT = int(os.getenv("OKOME_REDIS_PORT", "6379"))

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_timeout=0.5
)


def sha256(s: str) -> str:
    """Generate SHA256 hash of string."""
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def key_planner(model: str, prompt: str, toolset_version: str, repo_hash: str) -> str:
    """
    Generate cache key for planner output.
    
    Args:
        model: Model identifier (e.g., "gpt-4")
        prompt: Planner prompt text
        toolset_version: Version of toolset (e.g., "v1.2.3")
        repo_hash: Git HEAD hash or repo state hash
    
    Returns:
        Cache key string
    """
    prompt_hash = sha256(prompt)
    return f"okome:planner:{model}:{prompt_hash}:{toolset_version}:{repo_hash}"


def key_model_meta(model: str) -> str:
    """Generate cache key for model metadata."""
    return f"okome:model_meta:{model}"


def key_rag(repo: str, chunk_hash: str) -> str:
    """Generate cache key for RAG chunk."""
    return f"okome:rag:{repo}:{chunk_hash}"


def key_tools(tool_version: str) -> str:
    """Generate cache key for tool discovery."""
    return f"okome:tools:{tool_version}"


def key_health(node: str) -> str:
    """Generate cache key for health check."""
    return f"okome:health:{node}"


def get_json(key: str) -> Optional[Any]:
    """
    Get JSON value from Redis cache.
    
    Args:
        key: Cache key
    
    Returns:
        Deserialized JSON value or None if not found
    """
    try:
        val = r.get(key)
        return json.loads(val) if val else None
    except (redis.RedisError, json.JSONDecodeError):
        return None


def set_json(key: str, value: Any, ttl_seconds: int) -> None:
    """
    Set JSON value in Redis cache with TTL.
    
    Args:
        key: Cache key
        value: Value to cache (will be JSON serialized)
        ttl_seconds: Time to live in seconds
    """
    try:
        r.setex(key, ttl_seconds, json.dumps(value, separators=(",", ":")))
    except (redis.RedisError, TypeError):
        pass


def with_lock(lock_key: str, ttl_seconds: int = 10) -> bool:
    """
    Acquire a distributed lock (prevents stampede).
    
    Args:
        lock_key: Lock key
        ttl_seconds: Lock TTL in seconds
    
    Returns:
        True if lock acquired, False otherwise
    """
    try:
        # SET key value NX EX ttl
        return bool(r.set(lock_key, "1", nx=True, ex=ttl_seconds))
    except redis.RedisError:
        return False


def release_lock(lock_key: str) -> None:
    """
    Release a distributed lock.
    
    Args:
        lock_key: Lock key
    """
    try:
        r.delete(lock_key)
    except redis.RedisError:
        pass


# TTL constants (in seconds)
TTL_MODEL_META = 86400  # 24h
TTL_PLANNER = 600  # 10 min (adjustable 5-15 min)
TTL_RAG = 1800  # 30 min (adjustable 30-60 min)
TTL_TOOLS = 600  # 10 min
TTL_HEALTH = 30  # 30 sec
