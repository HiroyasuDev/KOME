#!/bin/bash
# Deploy OKOME backend cache to nc01 (192.168.86.19 or OKOME_BACKEND_HOST).
# Sets static IP 192.168.86.19 (NetworkManager or dhcpcd), installs Redis per plan.
# Usage: ./deploy_backend_to_cn01.sh
# Requires: sshpass, target reachable

set -euo pipefail

HOST="${OKOME_BACKEND_HOST:-192.168.86.19}"
USER="${OKOME_BACKEND_USER:-ncadmin}"
PASS="${OKOME_BACKEND_PASS:-ussfitzgerald}"
TARGET_IP="192.168.86.19"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${REPO}/configs/redis-backend"

echo "=== Deploy OKOME backend to ${USER}@${HOST} ==="

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${USER}@${HOST}" "mkdir -p /tmp/redis-backend"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no "${CONFIG_DIR}/redis.conf" "${USER}@${HOST}:/tmp/redis-backend/redis.conf"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no "${SCRIPT_DIR}/install_backend_cache.sh" "${USER}@${HOST}:/tmp/install_backend_cache.sh"
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "chmod +x /tmp/install_backend_cache.sh"

# Run install via nohup so it survives SSH disconnect when static IP is applied (NetworkManager).
# If IP does not change, install runs to completion in background anyway.
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=5 "${USER}@${HOST}" \
  "nohup sudo /tmp/install_backend_cache.sh /tmp/redis-backend > /tmp/install_backend.log 2>&1 &"
echo "Install started in background (log: /tmp/install_backend.log). Waiting 60s for static IP + Redis..."
sleep 60

# Prefer new IP; fall back to original HOST if we didn't change IP
for addr in "$TARGET_IP" "$HOST"; do
  if sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${USER}@${addr}" "redis-cli ping" 2>/dev/null | grep -q PONG; then
    echo ""
    echo "Done. Redis at ${addr}:6379. Reconnect: sshpass -p '...' ssh ${USER}@${addr}"
    exit 0
  fi
done

echo ""
echo "Install may still be running. Reconnect at ${TARGET_IP} or ${HOST} and check: tail -f /tmp/install_backend.log; redis-cli ping"
exit 1
