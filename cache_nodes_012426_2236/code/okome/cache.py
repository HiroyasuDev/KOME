# OKOME – Redis cache helper (stub)
# Plan: okome_two-node_cache_architecture_implementation
# TODO: Redis connection, cache keys (planner, RAG, model meta), TTL.

OKOME_REDIS_HOST = "192.168.86.19"
OKOME_REDIS_PORT = 6379

# Key schema: okome:model_meta:{model}, okome:planner:..., okome:rag:..., etc.
