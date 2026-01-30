# VIP Clarification — Do You Need a Separate RPi3?

**Short Answer**: **No. You do NOT need a separate Raspberry Pi for the VIP.**

---

## What is the VIP?

The VIP (Virtual IP) is **not a machine**. It is a **virtual IP address** (192.168.86.18) managed by `keepalived` software.

## How It Works

```
[ RPi3 A ] ← owns VIP (active, priority 150)
[ RPi3 B ] ← watches + takes VIP if A fails (backup, priority 100)
```

The VIP "floats" between the two frontend cache nodes:
- When Node A is healthy → Node A owns the VIP
- When Node A fails → Node B automatically claims the VIP (~2 seconds)

## Correct Architecture

For OKOME, you need **exactly 2 Raspberry Pis**:

1. **Frontend Cache Node** (192.168.86.20) - Nginx
2. **Backend Cache Node** (192.168.86.19) - Redis

The VIP (192.168.86.18) is managed by keepalived running on the frontend nodes. **No third Pi is needed.**

## When You WOULD Need a Third Node

Only if:

- You wanted **N+2 redundancy** (rare, unnecessary here)
- You wanted **frontend + backend caches both HA independently**
- You were running a **multi-site edge**

For OKOME's use case: **2 Pis is the correct architecture**.  
Anything more is wasted complexity.

## Configuration

The VIP is configured in:
- `configs/keepalived/keepalived-master.conf` (active node)
- `configs/keepalived/keepalived-backup.conf` (backup node)

Both configs run on frontend cache nodes. The backup node can be a cold spare that only activates when the active node fails.

## Verification

Check which node owns the VIP:

```bash
# On Node A
ip addr show | grep 192.168.86.18

# On Node B
ip addr show | grep 192.168.86.18
```

Only one node should show the VIP at any time.

---

**Verdict**: Stick with **2 RPi3s total**. The VIP is software-managed, not hardware.

---

**Last Updated**: 2026-01-24
