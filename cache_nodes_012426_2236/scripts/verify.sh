#!/bin/bash
# OKOME Two-Node – verify frontend (192.168.86.20) and backend (192.168.86.19)
# Usage: ./verify.sh [FRONTEND_HOST] [BACKEND_HOST]

set -euo pipefail

FRONTEND="${1:-192.168.86.20}"
BACKEND="${2:-192.168.86.19}"
USER="${OKOME_USER:-ncadmin}"
FRONTEND_PASS="${OKOME_FRONTEND_PASS:-usshopper}"
BACKEND_PASS="${OKOME_BACKEND_PASS:-ussfitzgerald}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OKOME Two-Node Verify ==="
echo "Frontend: ${FRONTEND}  Backend: ${BACKEND}"
echo ""

FAIL=0

# Frontend (Nginx) – OK if Nginx responds (200–504). 504 = upstream down, still ready.
echo "--- Frontend (${FRONTEND}) ---"
code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${FRONTEND}/" 2>/dev/null || echo "000")
if [[ "$code" =~ ^(200|301|302)$ ]]; then
  echo "  OK: HTTP ${code} (upstream reachable)"
elif [[ "$code" =~ ^(502|503|504)$ ]]; then
  echo "  OK: HTTP ${code} (Nginx up; upstream 192.168.86.25:8000 down or slow)"
else
  echo "  FAIL: HTTP ${code} (Nginx unreachable or timeout)"; FAIL=1
fi
hit=$(curl -s -D - -o /dev/null --connect-timeout 3 --max-time 8 "http://${FRONTEND}/assets/" 2>/dev/null | grep -i "X-Cache-Status" || true)
[ -n "$hit" ] && echo "  OK: X-Cache-Status present" || echo "  WARN: X-Cache-Status missing (or upstream down)"

# Backend (Redis)
echo ""
echo "--- Backend (${BACKEND}) ---"
out=$(sshpass -p "$BACKEND_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${USER}@${BACKEND}" "redis-cli ping 2>/dev/null" || true)
if echo "$out" | grep -q PONG; then
  echo "  OK: Redis PONG"
else
  echo "  FAIL: Redis"; FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "Two-node verify passed."
else
  echo "Some checks failed."
  exit 1
fi
