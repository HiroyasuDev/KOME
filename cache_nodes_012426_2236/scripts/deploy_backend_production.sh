#!/bin/bash
# Deploy OKOME backend live production config to 192.168.86.19
# Uploads configs + reconfigure script, runs production setup.
# Usage: ./deploy_backend_production.sh [HOST]

set -euo pipefail

HOST="${1:-192.168.86.19}"
USER="${OKOME_BACKEND_USER:-ncadmin}"
PASS="${OKOME_BACKEND_PASS:-ussfitzgerald}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIGS="${REPO}/configs"
REMOTE_BASE="/tmp/okome-backend-production"

echo "=== Deploy OKOME backend live production to ${USER}@${HOST} ==="

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${USER}@${HOST}" "mkdir -p ${REMOTE_BASE}/configs/redis-backend ${REMOTE_BASE}/scripts"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${CONFIGS}/redis-backend/redis.conf" \
  "${USER}@${HOST}:${REMOTE_BASE}/configs/redis-backend/"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${CONFIGS}/sysctl-okome.conf" \
  "${CONFIGS}/journald-okome.conf" \
  "${USER}@${HOST}:${REMOTE_BASE}/configs/" 2>/dev/null || true
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${SCRIPT_DIR}/reconfigure_backend_production.sh" \
  "${USER}@${HOST}:${REMOTE_BASE}/scripts/"
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "chmod +x ${REMOTE_BASE}/scripts/reconfigure_backend_production.sh"

echo "Running production reconfig..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=15 "${USER}@${HOST}" \
  "sudo ${REMOTE_BASE}/scripts/reconfigure_backend_production.sh ${REMOTE_BASE}"

echo ""
echo "Verifying..."
"${SCRIPT_DIR}/verify_backend.sh" "$HOST"
