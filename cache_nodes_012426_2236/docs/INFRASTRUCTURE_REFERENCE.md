# KOME Infrastructure Reference — Strict IPs & GPU Host

**Source**: Ingested from Cursor GPU server SSH connection and OKOME optimization context.  
**Purpose**: Single reference for the four addresses KOME focuses on and how to verify/connect to the GPU host.

---

## Strict IP Focus (KOME Scope) — Path Through OKOME .25

| IP | Role | Notes |
|----|------|--------|
| **192.168.86.25** | OKOME Web UI / Gateway | **Single path** for all traffic; OKOME talks to .30 (GPU) and .19 (Redis) internally |
| **192.168.86.20** | Frontend (Nginx) | All traffic to .25 only; no buffering for API/stream; cache + failure handling |
| **192.168.86.30** | GPU host (inference) | Used by OKOME on .25 — not proxied directly by KOME |
| **192.168.86.19** | Backend cache (Redis) | Used by OKOME on .25 — planner, RAG; never live tokens at edge |

KOME exists solely to support OKOME at **192.168.86.25** with full throughput and failure handling on the path Browser → .20 → .25.

---

## 192.168.86.30 — CORE GPU Host (NVCR)

### Identity

- **Hostname**: NVCR (Windows; WSL2 present)
- **OS**: Windows 11; SSH lands on Windows; WSL2 used for Ollama/vLLM/TensorFlow
- **SSH user**: `nervcentre` (key-based auth preferred once key is in `authorized_keys`)
- **Role**: Authoritative inference — heavy reasoning, tool execution; TensorFlow + vLLM + Ollama
- **Ports**:
  - **8000** — vLLM (OpenAI-compatible `/v1/chat/completions`); streaming when vLLM is running
  - **11434** — Ollama API (`/api/generate`, `/api/chat`)
  - **8500** — TensorFlow Serving gRPC (when TF Serving is running)
  - **8501** — TensorFlow Serving REST (when TF Serving is running); OKOME .25 can use `TENSORFLOW_SERVING_URL=http://192.168.86.30:8501`

### Verification (from LAN)

```bash
# Reachability
ping -c 3 192.168.86.30

# vLLM (port 8000) — streaming test
curl http://192.168.86.30:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-r1-14b","messages":[{"role":"user","content":"count to 10"}],"stream":true}'

# Ollama (port 11434) — version
curl -s http://192.168.86.30:11434/api/version

# TensorFlow Serving (port 8501) — model list
curl -s http://192.168.86.30:8501/v1/models
```

### SSH

- From a host that can reach .30: `ssh nervcentre@192.168.86.30`
- Passwordless: add your public key to `nervcentre`’s `~/.ssh/authorized_keys` on the GPU host (e.g. from Production 192.168.86.25: `ssh-copy-id -i ~/.ssh/id_ed25519.pub nervcentre@192.168.86.30`)
- If SSH fails: confirm username, key, and that the server allows key auth; RDP to 192.168.86.30 (Microsoft Remote Desktop, no gateway) to fix SSH or add keys in WSL2

### RDP (for console access)

- **PC name**: `192.168.86.30` (no gateway)
- **Port**: 3389
- Ensure Remote Desktop is enabled on the Windows host and firewall allows TCP 3389

### Optimization & persistence (OKOME repo)

Full GPU optimization, Ollama/vLLM tuning, WSL baseline, and persistence (Ollama at logon, swappiness, etc.) are maintained in the **OKOME** repo, not in KOME:

- **OKOME** `docs/ops/GPU_HOST_192_168_86_30_OPTIMIZATION.md` — optimization order, vLLM/Ollama tuning
- **OKOME** `docs/ops/GPU_HOST_192_168_86_30_STATUS.md` — current status
- **OKOME** `docs/ops/GPU_HOST_192_168_86_30_PERSISTENCE.md` — persistence (WSL, Task Scheduler)
- **OKOME** `scripts/gpu-host/` — baseline, Ollama start, Windows task scripts

KOME only routes traffic to .25; OKOME on .25 talks to .30 (TensorFlow, vLLM, Ollama). All runtime tuning and persistence are done in OKOME.

**TensorFlow integration**: See [GPU_HOST_TENSORFLOW_INTEGRATION.md](GPU_HOST_TENSORFLOW_INTEGRATION.md) for TF Serving (8500/8501) and OKOME .25 config.

---

## 10-Node EDGE (192.168.86.41–50)

| Nodes | IPs | Role |
|-------|-----|------|
| NODE-01/02 | .41, .42 | Ingress + Router (NGINX/Envoy, sticky routing) |
| NODE-03–06 | .43–.46 | Edge Cache / Stream (Redis, streaming workers) |
| NODE-07/08 | .47, .48 | Speculative GPU (draft tokens, smaller GPUs) |
| NODE-09/10 | .49, .50 | Control / Observability (Prometheus, Grafana, Loki) |

See [DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md) for roles, base config (Ubuntu LTS, governor, network, fd), and how they integrate with CORE GPU (.30) and OKOME (.25).

---

## 192.168.86.20 — Frontend (Nginx)

- **Role**: All traffic to OKOME .25 only; no buffering for API/stream; cache + failure handling
- **Streaming**: `proxy_buffering off`, `proxy_request_buffering off`, long timeouts for inference
- See [STREAMING_ARCHITECTURE.md](../STREAMING_ARCHITECTURE.md) and Nginx configs in `configs/nginx-frontend/`

---

## 192.168.86.19 — Backend (Redis)

- **Role**: Planner, RAG, metadata; never live token streams
- **Port**: 6379
- Verify: `redis-cli -h 192.168.86.19 ping`

---

## 192.168.86.25 — OKOME Web UI / Gateway

- **Role**: Single path for all traffic; OKOME routes to CORE GPU (.30) for TensorFlow, vLLM, Ollama; can use EDGE nodes (41–50) for cache, streaming, speculation, observability
- **TensorFlow**: Configure `TENSORFLOW_SERVING_URL=http://192.168.86.30:8501` (and gRPC if needed); see [GPU_HOST_TENSORFLOW_INTEGRATION.md](GPU_HOST_TENSORFLOW_INTEGRATION.md)

---

## Related KOME Docs

- [STREAMING_ARCHITECTURE.md](../STREAMING_ARCHITECTURE.md) — path through OKOME .25, Nginx requirements
- [STREAMING_DATA_PLANE.md](STREAMING_DATA_PLANE.md) — **who owns SSE/WS** (NODE-03–06); control vs stream plane; buffering, retry, backpressure
- [GPU_RESOURCE_ARBITRATION.md](GPU_RESOURCE_ARBITRATION.md) — **TF vs vLLM vs Ollama on .30**; shared vs partitioned GPU; limits, load-shed, failure modes
- [DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md) — 10-node EDGE (41–50), roles, base config
- [GPU_HOST_TENSORFLOW_INTEGRATION.md](GPU_HOST_TENSORFLOW_INTEGRATION.md) — TensorFlow on .30 and OKOME .25 integration
- [VIP_CLARIFICATION.md](VIP_CLARIFICATION.md) — VIP 192.168.86.18 (keepalived)
- [06_SRE_RUNBOOK.md](../06_SRE_RUNBOOK.md) — incidents, including streaming (INCIDENT 5b)

---

*Last updated: 2026-01-30 (ingested from cursor_gpu_server_ssh_connection.md)*
