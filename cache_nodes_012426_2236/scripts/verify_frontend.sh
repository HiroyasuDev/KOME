#!/bin/bash
# OKOME Frontend – verify 192.168.86.20 (CN00) production state
# Usage: ./verify_frontend.sh [HOST]

set -euo pipefail

HOST="${1:-192.168.86.20}"
USER="${OKOME_FRONTEND_USER:-ncadmin}"
PASS="${OKOME_FRONTEND_PASS:-usshopper}"

echo "=== Verify OKOME Frontend (${HOST}) ==="
echo ""

run() {
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "$@"
}

FAIL=0

out=$(run "systemctl is-active nginx 2>/dev/null" || true)
if [ "$out" = "active" ]; then
  echo "  OK: nginx active"
else
  echo "  FAIL: nginx not active"; FAIL=1
fi

out=$(run "systemctl is-enabled nginx 2>/dev/null" || true)
if [ "$out" = "enabled" ]; then
  echo "  OK: nginx enabled"
else
  echo "  WARN: nginx not enabled"
fi

out=$(run "ip -4 addr show eth0 2>/dev/null | grep 192.168.86.20" || true)
if [ -n "$out" ]; then
  echo "  OK: Static IP 192.168.86.20 on eth0"
else
  echo "  WARN: 192.168.86.20 not on eth0"
fi

out=$(run "sudo test -f /etc/nginx/conf.d/okome-frontend.conf && sudo grep -q 'kome_orchestrator' /etc/nginx/conf.d/okome-frontend.conf && echo ok" 2>/dev/null || true)
if [ "$out" = "ok" ]; then
  echo "  OK: okome-frontend.conf deployed (upstream 192.168.86.25:8000)"
else
  echo "  FAIL: okome-frontend.conf missing or invalid"; FAIL=1
fi

out=$(run "sudo test -d /var/cache/nginx/okome && echo ok" 2>/dev/null || true)
if [ "$out" = "ok" ]; then
  echo "  OK: cache dir /var/cache/nginx/okome exists"
else
  echo "  WARN: cache dir missing"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "Frontend production checks passed."
else
  echo "Some checks failed."
  exit 1
fi
