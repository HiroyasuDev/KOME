#!/usr/bin/env bash
# Deploy base config + role-specific config to EDGE nodes 41–50.
# Run from a host that can SSH to 192.168.86.41–50 (e.g. OKOME .25 or your workstation).
# Set EDGE_USER (default okome), EDGE_PASS or use key auth. See docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md.

set -euo pipefail

EDGE_USER="${EDGE_USER:-okome}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
BASE="${SCRIPT_DIR}/.."

# NODE-01/02 Ingress, NODE-03–06 Cache/Stream, NODE-07/08 Speculative GPU, NODE-09/10 Observability
declare -A NODES
NODES[41]=ingress
NODES[42]=ingress
NODES[43]=cache-stream
NODES[44]=cache-stream
NODES[45]=cache-stream
NODES[46]=cache-stream
NODES[47]=speculative-gpu
NODES[48]=speculative-gpu
NODES[49]=observability
NODES[50]=observability

REMOTE_DIR="${REMOTE_DIR:-/tmp/okome-edge-deploy}"

run_remote() {
  local ip=$1
  shift
  if [[ -n "${EDGE_PASS:-}" ]]; then
    sshpass -p "$EDGE_PASS" ssh -o StrictHostKeyChecking=no "${EDGE_USER}@${ip}" "$@"
  else
    ssh -o StrictHostKeyChecking=no "${EDGE_USER}@${ip}" "$@"
  fi
}

scp_remote() {
  local ip=$1
  local src=$2
  local dest=$3
  if [[ -n "${EDGE_PASS:-}" ]]; then
    sshpass -p "$EDGE_PASS" scp -o StrictHostKeyChecking=no -r "$src" "${EDGE_USER}@${ip}:${dest}"
  else
    scp -o StrictHostKeyChecking=no -r "$src" "${EDGE_USER}@${ip}:${dest}"
  fi
}

echo "Deploying EDGE nodes 41–50 (base + role)..."
echo "User: ${EDGE_USER}; set EDGE_PASS=... if using password auth"
echo ""

for i in 41 42 43 44 45 46 47 48 49 50; do
  ip="192.168.86.${i}"
  role="${NODES[$i]}"
  echo "--- ${ip} (NODE-$(printf '%02d' $((i-40)))) role=${role} ---"
  run_remote "$ip" "mkdir -p ${REMOTE_DIR}/configs ${REMOTE_DIR}/scripts" || { echo "WARN: ${ip} SSH failed"; continue; }
  scp_remote "$ip" "${SCRIPT_DIR}/../../configs/edge-nodes/" "${REMOTE_DIR}/configs/" || true
  scp_remote "$ip" "${SCRIPT_DIR}/apply-base-config.sh" "${SCRIPT_DIR}/apply-role-${role}.sh" "${REMOTE_DIR}/scripts/" || true
  run_remote "$ip" "CONFIGS=${REMOTE_DIR}/configs bash ${REMOTE_DIR}/scripts/apply-base-config.sh" || { echo "WARN: ${ip} base failed"; continue; }
  run_remote "$ip" "bash ${REMOTE_DIR}/scripts/apply-role-${role}.sh" || true
  echo "OK: ${ip} done"
done

echo ""
echo "Done. Verify: curl -I http://192.168.86.41/ (Ingress), redis-cli -h 192.168.86.43 ping (Cache), Grafana on .49/.50"
