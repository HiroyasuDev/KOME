# Phase 3: Cache-Aware Planner & Rate Limiting

**Status**: Stub. Implement per plan.

- `code/okome/cache.py`: Redis connection, cache keys (planner, RAG, model meta), TTL
- `code/okome/budget.py`: rate limiting, cache write budget, cardinality caps
- Planner endpoint uses cache + stampede locks
- Response headers: X-OKOME-Cache, X-OKOME-Cache-Key
- Nginx rate limiting: UI vs API zones

**Deliverables**: `code/okome/cache.py`, `budget.py`, `planner_example.py`, updated Nginx config.
