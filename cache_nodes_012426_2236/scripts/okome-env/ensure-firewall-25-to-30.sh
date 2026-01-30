#!/usr/bin/env bash
# Ensure firewall on CORE GPU 192.168.86.30 allows 8500 (gRPC) and 8501 (REST) from OKOME 192.168.86.25.
# Run ON 192.168.86.30 (Linux). For Windows/WSL2 on .30, allow 8500/8501 in Windows Firewall from .25.

set -euo pipefail

OKOME_IP="${OKOME_IP:-192.168.86.25}"
TF_GRPC_PORT="${TF_GRPC_PORT:-8500}"
TF_REST_PORT="${TF_REST_PORT:-8501}"

echo "Allowing ${OKOME_IP} to reach this host on ports ${TF_GRPC_PORT} (gRPC) and ${TF_REST_PORT} (REST)..."

if command -v ufw &>/dev/null; then
  sudo ufw allow from "${OKOME_IP}" to any port "${TF_GRPC_PORT}" comment "TensorFlow Serving gRPC from OKOME"
  sudo ufw allow from "${OKOME_IP}" to any port "${TF_REST_PORT}" comment "TensorFlow Serving REST from OKOME"
  sudo ufw status | grep -E "${TF_GRPC_PORT}|${TF_REST_PORT}" || true
  echo "Done (ufw). Reload with: sudo ufw reload"
elif command -v iptables &>/dev/null; then
  sudo iptables -C INPUT -p tcp -s "${OKOME_IP}" --dport "${TF_GRPC_PORT}" -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT -p tcp -s "${OKOME_IP}" --dport "${TF_GRPC_PORT}" -j ACCEPT
  sudo iptables -C INPUT -p tcp -s "${OKOME_IP}" --dport "${TF_REST_PORT}" -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT -p tcp -s "${OKOME_IP}" --dport "${TF_REST_PORT}" -j ACCEPT
  echo "Done (iptables). Persist rules per your distro (e.g. iptables-save)."
else
  echo "No ufw/iptables found. On Windows .30: allow TCP 8500 and 8501 from 192.168.86.25 in Windows Firewall."
fi

echo "From OKOME (.25) verify: curl -s http://192.168.86.30:${TF_REST_PORT}/v1/models"
