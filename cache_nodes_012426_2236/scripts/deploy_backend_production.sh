#!/bin/bash
# Deploy OKOME backend live production config to 192.168.86.19
# Uploads configs + reconfigure script, runs production setup.
# Handles both fresh (install Redis first) and existing nodes.
# Usage: ./deploy_backend_production.sh [HOST]

set -euo pipefail

HOST="${1:-192.168.86.19}"
TARGET_IP="192.168.86.19"
USER="${OKOME_BACKEND_USER:-ncadmin}"
PASS="${OKOME_BACKEND_PASS:-ussfitzgerald}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIGS="${REPO}/configs"
REMOTE_BASE="/tmp/okome-backend-production"

echo "=== Deploy OKOME backend live production to ${USER}@${HOST} ==="

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${USER}@${HOST}" "mkdir -p ${REMOTE_BASE}/configs/redis-backend ${REMOTE_BASE}/configs ${REMOTE_BASE}/scripts"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${CONFIGS}/redis-backend/redis.conf" \
  "${USER}@${HOST}:${REMOTE_BASE}/configs/redis-backend/"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${CONFIGS}/sysctl-okome.conf" \
  "${CONFIGS}/journald-okome.conf" \
  "${USER}@${HOST}:${REMOTE_BASE}/configs/" 2>/dev/null || true
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${SCRIPT_DIR}/reconfigure_backend_production.sh" \
  "${SCRIPT_DIR}/install_backend_cache.sh" \
  "${USER}@${HOST}:${REMOTE_BASE}/scripts/"
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "chmod +x ${REMOTE_BASE}/scripts/reconfigure_backend_production.sh ${REMOTE_BASE}/scripts/install_backend_cache.sh"

# Detect fresh node: Redis not installed
REDIS_INSTALLED=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${USER}@${HOST}" "command -v redis-server >/dev/null 2>&1 && dpkg -l redis-server 2>/dev/null | grep -q '^ii' && echo yes" || true)

if [ "$REDIS_INSTALLED" != "yes" ]; then
  echo "Fresh node: installing Redis (static IP, hostname, Redis)..."
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=5 "${USER}@${HOST}" \
    "nohup sudo ${REMOTE_BASE}/scripts/install_backend_cache.sh ${REMOTE_BASE}/configs/redis-backend > /tmp/install_backend.log 2>&1 &"
  echo "Install started in background (log: /tmp/install_backend.log). Waiting 60s for static IP + Redis..."
  sleep 60
fi

# Run reconfig (idempotent). Prefer TARGET_IP in case install changed IP.
RECONFIG_HOST="$TARGET_IP"
for addr in "$TARGET_IP" "$HOST"; do
  if sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${USER}@${addr}" "true" 2>/dev/null; then
    RECONFIG_HOST="$addr"
    break
  fi
done

echo "Running production reconfig on ${RECONFIG_HOST}..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=15 "${USER}@${RECONFIG_HOST}" \
  "sudo ${REMOTE_BASE}/scripts/reconfigure_backend_production.sh ${REMOTE_BASE}"

echo ""
echo "Verifying..."
"${SCRIPT_DIR}/verify_backend.sh" "$RECONFIG_HOST"
