"""
OKOME Budget Enforcement Module
Rate limiting and cache write budget enforcement per agent
"""

import time
from typing import Tuple
import redis
import os

REDIS_HOST = os.getenv("OKOME_REDIS_HOST", "192.168.86.19")
REDIS_PORT = int(os.getenv("OKOME_REDIS_PORT", "6379"))
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    decode_responses=True,
    socket_timeout=0.5
)


def _window_key(prefix: str, agent_id: str, window_seconds: int) -> str:
    """Generate window-based key for sliding window rate limiting."""
    window = int(time.time() // window_seconds)
    return f"{prefix}:{agent_id}:{window}"


def allow_rate(agent_id: str, limit: int, window_seconds: int = 60) -> Tuple[bool, int]:
    """
    Check if agent is within rate limit.
    
    Uses fixed-window approach (good enough for cache protection).
    
    Args:
        agent_id: Agent identifier
        limit: Maximum requests per window
        window_seconds: Window size in seconds
    
    Returns:
        Tuple of (allowed, remaining)
    """
    k = _window_key("okome:budget:rl", agent_id, window_seconds)
    try:
        n = r.incr(k)
        if n == 1:
            r.expire(k, window_seconds + 2)
        remaining = max(0, limit - n)
        return (n <= limit, remaining)
    except redis.RedisError:
        # Fail-open for availability
        return (True, limit)


def allow_cache_write(agent_id: str, write_limit: int, window_seconds: int = 60) -> Tuple[bool, int]:
    """
    Check if agent is within cache write budget.
    
    Args:
        agent_id: Agent identifier
        write_limit: Maximum cache writes per window
        window_seconds: Window size in seconds
    
    Returns:
        Tuple of (allowed, remaining)
    """
    k = _window_key("okome:budget:writes", agent_id, window_seconds)
    try:
        n = r.incr(k)
        if n == 1:
            r.expire(k, window_seconds + 2)
        remaining = max(0, write_limit - n)
        return (n <= write_limit, remaining)
    except redis.RedisError:
        # Fail-open for availability
        return (True, write_limit)


def record_agent_key(agent_id: str, cache_key: str, max_keys: int = 5000) -> bool:
    """
    Record cache key for agent and check cardinality cap.
    
    Prevents unique-key storms from runaway agents.
    
    Args:
        agent_id: Agent identifier
        cache_key: Cache key being written
        max_keys: Maximum unique keys per agent
    
    Returns:
        True if within cap, False if exceeded
    """
    sk = f"okome:agentkeys:{agent_id}"
    try:
        r.sadd(sk, cache_key)
        # Keep set from growing forever
        if r.scard(sk) > max_keys:
            return False
        r.expire(sk, 3600)  # Expire after inactivity
        return True
    except redis.RedisError:
        return True


# Default budget limits
DEFAULT_RATE_LIMIT = 60  # requests per minute
DEFAULT_WRITE_LIMIT = 30  # cache writes per minute
DEFAULT_MAX_KEYS = 5000  # max unique keys per agent
