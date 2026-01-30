# TensorFlow Integration — GPU Host (192.168.86.30) and OKOME (192.168.86.25)

**Scope**: Run TensorFlow (TF Serving or custom inference) on the CORE GPU host 192.168.86.30 and have OKOME at 192.168.86.25 call it for inference, alongside existing vLLM/Ollama.

---

## Roles

| Component | Role |
|-----------|------|
| **192.168.86.30 (CORE GPU)** | Hosts TensorFlow inference (TF Serving or custom API); also vLLM (:8000) and Ollama (:11434) for LLM workloads |
| **192.168.86.25 (OKOME)** | Gateway; routes requests to TensorFlow on .30 (and to vLLM/Ollama on .30); single path for users |

OKOME at .25 is responsible for choosing when to call TensorFlow vs vLLM/Ollama and for forwarding requests to the correct endpoint on .30.

---

## TensorFlow on 192.168.86.30

### Option A: TensorFlow Serving (recommended for production)

- **Ports**: REST **8501**, gRPC **8500** (default).
- **Model layout**: Export SavedModel; point TF Serving at the model directory.
- **Run** (example, Linux/WSL2 on .30):

  ```bash
  docker run -d --gpus all -p 8501:8501 -p 8500:8500 \
    -v /path/to/models:/models \
    tensorflow/serving:latest-gpu \
    --model_config_file=/models/models.config
  ```

  Or without Docker:

  ```bash
  tensorflow_model_server \
    --port=8500 \
    --rest_api_port=8501 \
    --model_name=my_model \
    --model_base_path=/path/to/saved_model
  ```

- **Health**: `curl http://192.168.86.30:8501/v1/models`
- **Predict (REST)**: `POST http://192.168.86.30:8501/v1/models/my_model:predict`

### Option B: Custom inference API (Flask/FastAPI + TensorFlow)

- Run a small REST API on .30 (e.g. port **8502**) that loads a Keras/SavedModel and exposes `/predict` or `/infer`.
- OKOME at .25 calls `http://192.168.86.30:8502/predict` (or similar).

### Port summary (192.168.86.30)

| Port | Service | Purpose |
|------|---------|--------|
| 8000 | vLLM | OpenAI-compatible LLM streaming |
| 11434 | Ollama | LLM API |
| **8500** | TF Serving gRPC | TensorFlow inference |
| **8501** | TF Serving REST | TensorFlow inference (REST) |
| 8502 | (optional) Custom TF API | Custom TensorFlow endpoint |

---

## OKOME (192.168.86.25) Integration

- **Configuration on OKOME**: Set the TensorFlow endpoint used by the app, e.g.:
  - `TENSORFLOW_SERVING_URL=http://192.168.86.30:8501`
  - Or for gRPC: `TENSORFLOW_SERVING_GRPC=192.168.86.30:8500`
- **Routing**: OKOME decides which backend to call (TensorFlow vs vLLM vs Ollama) based on model type or route; all outbound calls from OKOME go directly to 192.168.86.30 on the appropriate port.
- **No KOME frontend change**: Traffic still goes Browser → KOME frontend (.20) → OKOME (.25). OKOME (.25) → 192.168.86.30 (TensorFlow/vLLM/Ollama). No need to expose TensorFlow ports on the Nginx frontend unless you want a dedicated public path (then OKOME can proxy or Nginx can proxy to .25 which then calls .30).

---

## Verification

From a host that can reach 192.168.86.30 (e.g. OKOME at .25):

```bash
# TF Serving REST health
curl -s http://192.168.86.30:8501/v1/models

# TF Serving predict (example)
curl -X POST http://192.168.86.30:8501/v1/models/my_model:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [ ... ]}'
```

From OKOME (.25), ensure the app can reach `http://192.168.86.30:8501` (and 8500 if using gRPC). Firewall on .30 must allow 8500/8501 from .25.

---

## GPU and environment (192.168.86.30)

- **NVIDIA driver + CUDA**: Required for TensorFlow GPU. Match TensorFlow/CUDA versions (e.g. TF 2.12+ with CUDA 11.8 or 12).
- **WSL2 (Windows host)**: TensorFlow Serving or custom API can run in WSL2 with GPU passthrough; same ports (8500/8501) bound to 0.0.0.0 so .25 can connect.
- **Resource sharing**: If vLLM/Ollama and TensorFlow share the same GPU, set `CUDA_VISIBLE_DEVICES` or limit per-process memory so they do not OOM.

---

## 10-Node and TensorFlow

- **CORE GPU (.30)**: Runs authoritative TensorFlow (and vLLM/Ollama) for heavy reasoning and tool execution.
- **NODE-07/08 (speculative GPU)**: Can run lighter TensorFlow Lite or small models for draft tokens; OKOME or Ingress can route speculative requests to .47/.48 and authoritative ones to .30.
- **OKOME (.25)**: Integrates .30 (and optionally .47/.48) so that TensorFlow is used for the right workloads and the 10-node EDGE layer (Ingress, Cache/Stream, Observability) is used for routing, caching, and monitoring.

---

## Summary

- **TensorFlow on 192.168.86.30**: TF Serving REST :8501, gRPC :8500; or custom API on e.g. :8502.
- **OKOME 192.168.86.25**: Configure `TENSORFLOW_SERVING_URL=http://192.168.86.30:8501` (and gRPC if needed); route inference to TensorFlow/vLLM/Ollama on .30.
- **Path**: User → Ingress (e.g. .20 or NODE-01/02) → OKOME .25 → CORE GPU .30 (TensorFlow + vLLM + Ollama); EDGE nodes 41–50 used for cache, streaming, speculation, and observability as per [DISTRIBUTED_10_NODE_ARCHITECTURE.md](DISTRIBUTED_10_NODE_ARCHITECTURE.md).

---

## What you do next (enforced)

### 1. On 192.168.86.30 (CORE GPU)

- **Install and run TensorFlow Serving** (REST 8501, gRPC 8500, bind 0.0.0.0):
  - From this repo (run on .30 or copy scripts there):
    ```bash
    cd cache_nodes_012426_2236/scripts/tensorflow-serving
    ./install-tensorflow-serving-192.168.86.30.sh
    ```
  - Or use Docker (on .30): `docker run -d --gpus all -p 8500:8500 -p 8501:8501 -v /path/to/models:/models -e MODEL_NAME=my_model tensorflow/serving:latest-gpu`
  - Or use systemd: copy `configs/tensorflow-serving/tensorflow-serving.service` to `/etc/systemd/system/`, edit `ExecStart` with your model path, then `sudo systemctl daemon-reload && sudo systemctl enable --now tensorflow-serving`
- **Allow OKOME (.25) through firewall** (on .30):
  ```bash
  cache_nodes_012426_2236/scripts/okome-env/ensure-firewall-25-to-30.sh
  ```
- **Verify** (from any host that can reach .30):
  ```bash
  cache_nodes_012426_2236/scripts/tensorflow-serving/verify-tensorflow-serving.sh
  # or: curl -s http://192.168.86.30:8501/v1/models
  ```

### 2. On 192.168.86.25 (OKOME)

- **Set TensorFlow env** so the app can call .30:
  - Copy `configs/okome-env/okome-tensorflow.env.example` into your OKOME app env (e.g. `.env` or systemd `Environment=`):
    ```bash
    TENSORFLOW_SERVING_URL=http://192.168.86.30:8501
    TENSORFLOW_SERVING_GRPC=192.168.86.30:8500
    ```
  - Restart the OKOME app after setting these.
- **Ensure firewall/network**: .25 must be able to reach .30 on 8500 and 8501. Run `ensure-firewall-25-to-30.sh` on .30 (see above). On Windows .30, allow TCP 8500 and 8501 from 192.168.86.25 in Windows Firewall.

---

*Last updated: 2026-01-30*
