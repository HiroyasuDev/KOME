# Distributed 10-Node Architecture — CORE GPU + EDGE Nodes

**Scope**: 10 nodes (NODE-01 to NODE-10 at 192.168.86.41–50) plus CORE GPU (192.168.86.30) and OKOME gateway (192.168.86.25), designed for optimal performance and user experience in a distributed inference system.

---

## Role Separation

| Layer | Role | Purpose |
|-------|------|--------|
| **CORE GPU (192.168.86.30)** | Authoritative inference | Heavy reasoning, tool execution, TensorFlow/vLLM/Ollama; single source of truth for model output |
| **EDGE Nodes (192.168.86.41–50)** | Streaming, cache, routing, UX | Sticky routing, caching, speculative draft tokens, observability |
| **OKOME (192.168.86.25)** | Gateway / Web UI | Single path for traffic; routes to CORE GPU (.30), TensorFlow, and EDGE as needed |

---

## Node Classification (192.168.86.41–50)

| Nodes | Hostnames | IPs | Role | Stack |
|-------|-----------|-----|------|--------|
| **NODE-01 / NODE-02** | okome-node-01, okome-node-02 | .41, .42 | **Ingress + Router** | NGINX or Envoy; stable connections; sticky/session affinity routing to backend |
| **NODE-03 – NODE-06** | okome-node-03 … 06 | .43 – .46 | **Edge Cache / Stream** | Redis (cache); streaming workers; smooth data flow; low-latency proxy |
| **NODE-07 / NODE-08** | okome-node-07, 08 | .47, .48 | **Speculative GPU** | Smaller GPUs for draft tokens; optional TensorFlow Lite or small models for speculation |
| **NODE-09 / NODE-10** | okome-node-09, 10 | .49, .50 | **Control / Observability** | Prometheus, Grafana, Loki; metrics, logs, dashboards; alerting |

---

## End-to-End Flow (with OKOME .25)

**Current (path through .25)**: All traffic goes through OKOME .25; .25 calls CORE GPU (.30) and EDGE as needed.

**Target (stream plane)**: Token path bypasses .25; NODE-03–06 own SSE/WS. See [STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md).

```
User (Browser)
    ↓  SSE / WebSocket
NODE-01 or NODE-02 (Ingress) — TLS + stickiness
    ↓  sticky → same stream node
NODE-03..06 (Edge Stream) — holds SSE/WS, buffers tokens, backpressure
    ↓  authoritative tokens
    ↘  CORE GPU 192.168.86.30 (TensorFlow / vLLM / Ollama)
    ↕  control only (auth, model choice, tool policy)
OKOME 192.168.86.25 — not in token path (control plane)
    └── Metrics / logs ───────────► NODE-09/10 (Prometheus, Grafana, Loki)
```

- **Control plane**: OKOME (.25) — auth/session, routing policy, tool orchestration, model selection, metadata. **Not** per-token relay.
- **Stream plane**: NODE-03–06 — hold SSE/WS, receive tokens from .30, stream to client with buffering/backpressure.
- **CORE GPU (.30)**: TF vs vLLM vs Ollama arbitration and limits — see [GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md).

---

## Base Configuration (All Nodes)

Applicable to EDGE nodes (41–50) and, where relevant, to CORE GPU (.30) and OKOME (.25):

### OS & kernel

- **OS**: Ubuntu Server LTS (22.04 or 24.04) recommended.
- **CPU governor**: Performance for low latency.
  ```bash
  sudo apt install linux-tools-common
  sudo cpupower frequency-set -g performance
  ```
- **Persist**: e.g. systemd unit or cron to set governor on boot.

### Network tuning (high concurrency, low latency)

```bash
# /etc/sysctl.d/99-okome-distributed.conf
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8192
vm.swappiness = 10
```

Apply: `sudo sysctl -p /etc/sysctl.d/99-okome-distributed.conf`

### File descriptors (streaming stability)

- **System**: `fs.file-max = 2097152` in sysctl.
- **Process**: For NGINX/Envoy/streaming workers, set `nofile` (e.g. 65535) in `/etc/security/limits.d/99-okome.conf` and in the service unit.

### Optional: latency budget per hop

- Define target latency per hop (e.g. Ingress &lt; 5 ms, Cache &lt; 2 ms, CORE GPU first-token &lt; 500 ms) and monitor via Prometheus (NODE-09/10) to stay within budget.

---

## Optimization Considerations

| Topic | Recommendation |
|-------|----------------|
| **Kubernetes vs bare-metal** | Start bare-metal for predictability and latency; consider K8s later for scaling EDGE nodes (03–10) if needed. CORE GPU (.30) and OKOME (.25) can stay bare-metal. |
| **Latency budget** | Instrument each hop (Ingress → OKOME → CORE/EDGE); alert on SLO breach from Grafana (NODE-09/10). |
| **Failure drills** | Periodically isolate CORE GPU (.30) or OKOME (.25) to test: Ingress/EDGE failover, cache serving, and observability (Prometheus/Loki on 09/10). Document in SRE runbook. |
| **Sticky routing** | NODE-01/02 (NGINX/Envoy): use `hash $remote_addr` or `hash $cookie_*` for session affinity so a user sticks to the same backend where possible. |

---

## Relation to Existing KOME Topology

- **192.168.86.20** (current KOME frontend): Can be treated as the initial ingress or merged into NODE-01/02 (e.g. .20 = NODE-01, or .41/.42 = NODE-01/02). Traffic path remains: Browser → Ingress → OKOME .25 → CORE GPU .30 (and optionally EDGE 41–50).
- **192.168.86.19** (Redis): Can remain the central cache used by OKOME .25, or be extended by Redis on NODE-03–06 for edge cache.
- **Path through OKOME .25**: Unchanged; OKOME at .25 is the single gateway that talks to CORE GPU (.30), TensorFlow on .30, and EDGE nodes (41–50) as needed.

---

## Summary

- **CORE GPU (192.168.86.30)**: Authoritative inference (TensorFlow, vLLM, Ollama); heavy reasoning and tool execution.
- **EDGE (41–50)**: NODE-01/02 Ingress/Router; NODE-03–06 Cache/Stream; NODE-07/08 Speculative GPU; NODE-09/10 Observability.
- **OKOME (192.168.86.25)**: Single gateway; integrates CORE GPU and TensorFlow with the 10-node EDGE layer for performance, reliability, and scalability.

---

## What you do next (enforced)

### Base config and role scripts (EDGE 41–50)

Configs and scripts in this repo **enforce** base OS/network/fd and role-specific setup:

| Item | Path | Purpose |
|------|------|--------|
| Sysctl | `configs/edge-nodes/sysctl-99-okome-distributed.conf` | High concurrency, low latency; deploy to `/etc/sysctl.d/` |
| Limits | `configs/edge-nodes/limits-99-okome.conf` | `nofile` 65535; deploy to `/etc/security/limits.d/` |
| Base (all nodes) | `scripts/edge-nodes/apply-base-config.sh` | Applies sysctl, limits, CPU governor |
| NODE-01/02 Ingress | `scripts/edge-nodes/apply-role-ingress.sh` | NGINX with sticky routing to OKOME .25 |
| NODE-03–06 Cache/Stream | `scripts/edge-nodes/apply-role-cache-stream.sh` | Redis + NGINX proxy to OKOME .25 |
| NODE-07/08 Speculative GPU | `scripts/edge-nodes/apply-role-speculative-gpu.sh` | Placeholder; add TF Lite / small model as needed |
| NODE-09/10 Observability | `scripts/edge-nodes/apply-role-observability.sh` | Prometheus, Grafana; Loki optional |
| **Orchestrator** | `scripts/edge-nodes/deploy-edge-nodes.sh` | SSHs to 41–50 and runs base + role script per node |

### Deploy all EDGE nodes (41–50)

From a host that can SSH to 192.168.86.41–50 (e.g. OKOME .25 or your workstation):

```bash
cd cache_nodes_012426_2236/scripts/edge-nodes
# Key-based auth (recommended):
./deploy-edge-nodes.sh

# Or with password (set EDGE_USER if not 'okome'):
EDGE_PASS='your_password' ./deploy-edge-nodes.sh
```

This copies configs and scripts to each node, runs **apply-base-config.sh** (sysctl, limits, governor), then the role script (ingress, cache-stream, speculative-gpu, or observability) per node.

### Deploy a single node manually

On the EDGE node (e.g. SSH to 192.168.86.41):

```bash
# Copy configs and scripts from repo to this node, then:
CONFIGS=/path/to/configs/edge-nodes bash apply-base-config.sh
bash apply-role-ingress.sh   # on .41 or .42
# or apply-role-cache-stream.sh on .43–.46, etc.
```

### Verify

- **Ingress (41/42)**: `curl -I http://192.168.86.41/` and `http://192.168.86.42/`
- **Cache/Stream (43–46)**: `redis-cli -h 192.168.86.43 ping`, `curl -I http://192.168.86.43/`
- **Observability (49/50)**: Grafana at `http://192.168.86.49:3000` (and .50)

---

*Last updated: 2026-01-30*
