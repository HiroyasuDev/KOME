#!/bin/bash
# Deploy OKOME frontend live production to 192.168.86.20
# Usage: ./deploy_frontend_production.sh [HOST]

set -euo pipefail

HOST="${1:-192.168.86.20}"
USER="${OKOME_FRONTEND_USER:-ncadmin}"
PASS="${OKOME_FRONTEND_PASS:-usshopper}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIGS="${REPO}/configs"
REMOTE_BASE="/tmp/okome-frontend-production"

echo "=== Deploy OKOME frontend live production to ${USER}@${HOST} ==="

sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${USER}@${HOST}" "mkdir -p ${REMOTE_BASE}/configs/nginx-frontend ${REMOTE_BASE}/scripts"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${CONFIGS}/nginx-frontend/okome-frontend.conf" \
  "${USER}@${HOST}:${REMOTE_BASE}/configs/nginx-frontend/"
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no \
  "${SCRIPT_DIR}/install_frontend_cache.sh" \
  "${USER}@${HOST}:${REMOTE_BASE}/scripts/"
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "chmod +x ${REMOTE_BASE}/scripts/install_frontend_cache.sh"

echo "Running frontend install..."
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=15 "${USER}@${HOST}" \
  "sudo ${REMOTE_BASE}/scripts/install_frontend_cache.sh ${REMOTE_BASE}"

echo ""
echo "Verifying..."
"${SCRIPT_DIR}/verify_frontend.sh" "$HOST"
