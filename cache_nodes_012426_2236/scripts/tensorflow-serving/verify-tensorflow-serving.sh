#!/usr/bin/env bash
# Verify TensorFlow Serving on CORE GPU 192.168.86.30 (REST 8501, gRPC 8500).
# Run from any host that can reach .30 (e.g. OKOME .25 or your workstation).

set -euo pipefail

GPU_HOST="${GPU_HOST:-192.168.86.30}"
REST_PORT="${TF_REST_PORT:-8501}"
GRPC_PORT="${TF_GRPC_PORT:-8500}"

echo "Checking TensorFlow Serving at ${GPU_HOST}:${REST_PORT} (REST) and :${GRPC_PORT} (gRPC)..."

if curl -fsS --max-time 5 "http://${GPU_HOST}:${REST_PORT}/v1/models" >/dev/null 2>&1; then
  echo "OK: REST API at http://${GPU_HOST}:${REST_PORT}/v1/models"
  curl -s "http://${GPU_HOST}:${REST_PORT}/v1/models" | head -20
else
  echo "FAIL: Cannot reach REST API at http://${GPU_HOST}:${REST_PORT}/v1/models"
  exit 1
fi

if nc -z -w 2 "${GPU_HOST}" "${GRPC_PORT}" 2>/dev/null; then
  echo "OK: gRPC port ${GRPC_PORT} open"
else
  echo "WARN: gRPC port ${GRPC_PORT} not reachable (optional)"
fi

echo "OKOME (.25) should set: TENSORFLOW_SERVING_URL=http://${GPU_HOST}:${REST_PORT}"
