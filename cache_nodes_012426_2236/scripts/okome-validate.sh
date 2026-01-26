#!/bin/bash
# OKOME Two-Node – one-command validation
# Usage: ./okome-validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="${OKOME_FRONTEND:-192.168.86.20}"
BACKEND="${OKOME_BACKEND:-192.168.86.19}"

echo "=== OKOME Two-Node Validate ==="
echo "Frontend: ${FRONTEND} (CN00)  Backend: ${BACKEND} (CN01)"
echo ""

echo "--- Frontend detail ---"
"${SCRIPT_DIR}/verify_frontend.sh" "$FRONTEND" || exit 1
echo ""

echo "--- Backend detail ---"
"${SCRIPT_DIR}/verify_backend.sh" "$BACKEND" || exit 1
echo ""

echo "--- Two-node connectivity ---"
"${SCRIPT_DIR}/verify.sh" "$FRONTEND" "$BACKEND" || exit 1

echo ""
echo "Validation complete. Both nodes ready."
