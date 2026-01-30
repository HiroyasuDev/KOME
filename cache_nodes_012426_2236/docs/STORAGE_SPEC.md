# Storage Specifications — OKOME Cache Nodes

**Target**: Raspberry Pi 3+ v1.5  
**Date**: 2026-01-24

---

## TL;DR (Buy This and Stop Thinking About It)

| Node | Role | Recommended Storage |
|------|------|---------------------|
| `192.168.86.20` | Frontend / Edge Cache | **32 GB microSD (A1-rated)** |
| `192.168.86.19` | Backend / Redis Cache | **32 GB microSD (A1-rated)** |

**32 GB is the sweet spot**  
16 GB is survivable but tight  
Anything above 32 GB is wasted money on RPi 3

---

## Frontend Cache Node (192.168.86.20)

### What It Stores

- Nginx binary + OS
- Cached:
  - `/assets/*`
  - `/ui-schema/*`
  - `/version`, `/health`
- Logs (rotated, in tmpfs)
- Zero write-heavy workloads

### Real Usage Breakdown

| Component | Space |
|-----------|-------|
| Raspberry Pi OS Lite | ~2 GB |
| Nginx + deps | <100 MB |
| Cached assets (worst case) | 1–2 GB |
| Logs + rotation | <500 MB |
| Safety buffer | ~3 GB |

**Total realistic use**: **~7–8 GB**

### Why 32 GB is Right

- Leaves ~20 GB free → no SD wear pressure
- Allows long cache retention (days)
- Prevents "disk full = dead cache" failures
- Cheap + reliable

**Do NOT** put swap on this node.  
**Do NOT** log verbosely.

---

## Backend Cache Node (192.168.86.19 – Redis)

### What It Stores

- OS + Redis
- Redis in-memory cache
- Minimal logs
- Optional persistence (disabled by default)

### Important Truth

> **Redis uses RAM first — storage is just a safety net**

Your Redis config:

```ini
maxmemory 4gb
appendonly no
save ""
```

So disk usage is **very low**.

### Real Usage Breakdown

| Component | Space |
|-----------|-------|
| Raspberry Pi OS Lite | ~2 GB |
| Redis binary | <50 MB |
| Logs | <200 MB |
| Temp / OS | <500 MB |
| Safety buffer | ~3 GB |

**Total realistic use**: **~6 GB**

### Why 32 GB Still Wins

- SD cards degrade when >80% full
- You want *boring stability*
- Allows optional future:
  - AOF (if ever enabled)
  - Redis snapshots
  - Local metrics

**Do NOT enable Redis persistence** on RPi 3  
**Treat Redis as disposable**

---

## Why Not 16 GB?

16 GB *works*, but:

- OS updates eat space fast
- Log misconfig = instant brick
- No room for troubleshooting
- SD wear accelerates

Use **16 GB only** if:

- You already own them
- You aggressively trim logs
- You accept higher failure risk

---

## SD Card Type Matters More Than Size

### Mandatory

- **A1-rated** microSD (random I/O optimized)
- Known brands only:
  - SanDisk Extreme
  - Samsung EVO / PRO
  - Kingston Canvas

### Avoid

- No-name cards
- "High speed" without A-rating
- Old cards reused from cameras

**Random I/O > sequential speed** for caches.

---

## Partitioning (Optional but Smart)

If you want extra safety:

### Frontend Node

- `/` → 8–10 GB
- `/var/cache/nginx` → rest

### Backend Node

- `/` → 8–10 GB
- `/var/log` → 1 GB cap

This prevents logs or cache from killing the OS.

---

## Filesystem & Mount Options (Highly Recommended)

Add to `/etc/fstab`:

```fstab
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0
```

And mount root with:

- `noatime`
- `commit=60`

This **dramatically increases SD lifespan**.

---

## Final Recommendation (Authoritative)

- **32 GB A1 microSD for both nodes**
- Raspberry Pi OS Lite (no desktop)
- No swap
- Minimal logging
- Treat caches as disposable

This gives you **months of uptime**, zero anxiety, and clean failure modes.

---

**Last Updated**: 2026-01-24
