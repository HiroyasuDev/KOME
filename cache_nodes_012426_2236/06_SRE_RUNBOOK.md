# OKOME Cache Layer — Golden Incident Runbook

**Scope**: Edge cache (Nginx), backend cache (Redis), VIP failover  
**Design principle**: *Stateless, disposable, fast recovery*

---

## Quick Answer: Do You Need a Separate RPi3 for the VIP?

**No. You do NOT need a separate Raspberry Pi for the VIP.**

### Why

- The **VIP is not a machine**
- It is a **virtual IP address** managed by `keepalived`
- It floats between:
  - Frontend cache Pi (active)
  - Cold-spare cache Pi (backup)

### Correct Model

```
[ RPi3 A ] ← owns VIP (active)
[ RPi3 B ] ← watches + takes VIP if A fails
```

### When You WOULD Need a Third Node

Only if:
- You wanted **N+2 redundancy** (rare, unnecessary here)
- You wanted **frontend + backend caches both HA independently**
- You were running a **multi-site edge**

For OKOME: **2 Pis is the correct architecture**.  
Anything more is wasted complexity.

**Verdict**: Stick with **2 RPi3s total**.

---

## Incident Runbooks

Each section has:
- **Symptom**
- **Impact**
- **Immediate action**
- **Verification**
- **Post-incident follow-up**

---

## INCIDENT 1 — UI is slow or blank

### Symptoms

- Browser hangs
- UI loads slowly
- Assets partially missing

### Likely Causes

1. Nginx cache unhealthy
2. Upstream orchestrator slow
3. Cache miss storm

### Immediate Actions (in order)

```bash
# From workstation
curl -I http://VIP/
```

Check headers:
- `X-Cache-Status: HIT` → cache working
- `MISS` → upstream load
- `503` → failover/maintenance

On frontend Pi:

```bash
ssh pi@192.168.86.20
systemctl status nginx
```

If nginx is down:

```bash
sudo systemctl restart nginx
```

### Verification

```bash
curl -I http://VIP/
```

Expect:

```
HTTP/1.1 200
X-OKOME-Node: frontend-cache
X-Cache-Status: HIT
```

### Follow-up

- Check prewarm timer:

```bash
systemctl status okome-prewarm.timer
```

- Review hit ratio:

```bash
awk '/cache=HIT|cache=MISS/' /var/log/nginx/okome_access.log
```

---

## INCIDENT 2 — Redis cache unavailable

### Symptoms

- Planner responses slower
- GPU load spikes
- `X-OKOME-Cache: MISS` frequently

### Immediate Actions

```bash
redis-cli -h 192.168.86.19 ping
```

If no `PONG`:

```bash
ssh pi@192.168.86.19
sudo systemctl restart redis-server
```

### Verification

```bash
redis-cli -h 192.168.86.19 info stats | egrep "hits|misses"
```

### Impact Note

**System remains functional**

- Redis is **non-authoritative**
- Planner recomputes safely

### Follow-up

- Check agent budgets:

```bash
redis-cli -h 192.168.86.19 keys "okome:budget:*" | wc -l
```

- Look for runaway agents

---

## INCIDENT 3 — VIP not responding

### Symptoms

- `curl http://192.168.86.18` fails
- Browser can't connect

### Immediate Actions

Check which Pi owns the VIP:

```bash
ip addr show | grep 192.168.86.18
```

If neither owns it:

```bash
sudo systemctl restart keepalived
```

(on **both** Pis)

### Verification

```bash
curl -I http://192.168.86.18/
```

### Follow-up

- Inspect keepalived logs:

```bash
journalctl -u keepalived --since "10 minutes ago"
```

---

## INCIDENT 4 — Frontend Pi is dead (power, SD, kernel panic)

### Symptoms

- SSH unreachable
- No response on its static IP
- VIP moved

### Expected Behavior (by design)

- Cold-spare Pi claims VIP in ~2 seconds
- UI continues serving (possibly stale cache)

### What to Do

**Nothing immediately**

Confirm:

```bash
curl -I http://VIP/
```

Then:
- Reflash dead Pi with golden image
- Boot → becomes new cold spare

### Post-incident

- Replace SD card if repeated
- Check power supply (common Pi failure)

---

## INCIDENT 5 — Upstream orchestrator down

### Symptoms

- `/api/*` returns 503
- UI still loads
- `X-Cache-Status: HIT` or `UPDATING`

### Expected Behavior

- Edge cache serves **stale UI**
- Planner/API calls fail gracefully

### Verification

```bash
curl -I http://VIP/
curl -I http://VIP/api/planner
```

### Action

- Fix orchestrator (`192.168.86.25`)
- Do **NOT** touch cache nodes

---

## INCIDENT 5b — Streaming slow or OKOME (192.168.86.25) path issues

### Architecture (path through OKOME .25 only)

All traffic goes through OKOME at **192.168.86.25**. KOME frontend (.20) does not buffer API/stream; long timeouts and retries. If streaming is slow, check OKOME (.25) and GPU (.30); KOME (.20) is configured for unbuffered pass-through to .25.

### Verification

From a host on LAN:

```bash
# OKOME health
curl -fsS --max-time 3 http://192.168.86.25:8000/health

# Via KOME frontend
curl -I http://192.168.86.20/
curl -I http://192.168.86.20/health
```

- **.25/health fails** → fix OKOME on 192.168.86.25.
- **.20 returns 503** → OKOME unhealthy; check health probe and .25.
- **Streaming slow** → ensure Nginx on .20 has for API/stream locations: `proxy_buffering off`, `proxy_request_buffering off`, `proxy_read_timeout 600s`, `proxy_send_timeout 600s`. See [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md).

### Golden rule

**Path through OKOME 192.168.86.25 only.** KOME (.20) = single upstream .25; no buffering for API/stream. See [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md). GPU host (.30) and Redis (.19) are used by OKOME internally; see [docs/INFRASTRUCTURE_REFERENCE.md](docs/INFRASTRUCTURE_REFERENCE.md).

---

## INCIDENT 6 — Cache miss storm / GPU overload

### Symptoms

- Redis hit ratio drops
- GPU pegged
- High planner latency

### Immediate Actions

1. Enable canary bypass to inspect:

```bash
curl -I -H "X-OKOME-Canary: debug" http://VIP/ui-schema/foo
```

2. Check agent budgets:

```bash
redis-cli -h 192.168.86.19 keys "okome:budget:rl:*"
```

3. Temporarily clamp budgets (safe):

```bash
redis-cli -h 192.168.86.19 flushdb
```

*(Redis is cache-only — this is safe)*

### Follow-up

- Reduce TTL churn
- Tune prewarm filters
- Inspect planner cache keys

---

## INCIDENT 7 — Chaos test triggered accidentally

### Symptoms

- nginx/redis stopped unexpectedly
- iptables rules appear

### Immediate Actions

```bash
ssh pi@NODE
sudo systemctl restart nginx redis-server keepalived
sudo iptables -F
```

Disable chaos:

```bash
sudo rm /etc/okome/CHAOS_ENABLE
```

---

## Operational Golden Rules (PRINT THESE)

1. **Never debug cache nodes first**
   → They are *symptoms*, not causes

2. **Redis can always be flushed**
   → It is safe by design

3. **VIP failure ≠ outage**
   → Check which node owns it

4. **If in doubt, reflash the Pi**
   → Faster than debugging SD weirdness

5. **Caches are cattle**
   → Treat them as replaceable

---

## Validation Script

Run one-command validation:

```bash
./cache_nodes_012426_2236/scripts/okome-validate.sh
```

This checks:
- SSH connectivity
- Nginx/Redis status
- Memory, disk, network
- Cache headers
- VIP ownership

---

## Storage Specifications

### Frontend Cache Node (192.168.86.20)

- **Recommended**: 32GB A1-rated microSD
- **Realistic use**: ~7-8 GB
- **Why 32GB**: Leaves ~20GB free, prevents SD wear pressure

### Backend Cache Node (192.168.86.19)

- **Recommended**: 32GB A1-rated microSD
- **Realistic use**: ~6 GB
- **Why 32GB**: SD cards degrade when >80% full

### SD Card Type

**Mandatory**:
- A1-rated microSD (random I/O optimized)
- Known brands: SanDisk Extreme, Samsung EVO/PRO, Kingston Canvas

**Avoid**:
- No-name cards
- "High speed" without A-rating
- Old cards reused from cameras

---

## Quick Reference

| Node | IP | Service | Port |
|------|-----|---------|------|
| VIP | 192.168.86.18 | keepalived | - |
| Frontend | 192.168.86.20 | Nginx | 80 |
| Backend | 192.168.86.19 | Redis | 6379 |
| Orchestrator | 192.168.86.25 | OKOME | 8000 |

---

**Last Updated**: 2026-01-24
