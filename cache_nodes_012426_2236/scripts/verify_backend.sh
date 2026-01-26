#!/bin/bash
# OKOME Backend – verify 192.168.86.19 production state
# Usage: ./verify_backend.sh [HOST]
# HOST defaults to 192.168.86.19. Runs checks via SSH.

set -euo pipefail

HOST="${1:-192.168.86.19}"
USER="${OKOME_BACKEND_USER:-ncadmin}"
PASS="${OKOME_BACKEND_PASS:-ussfitzgerald}"

echo "=== Verify OKOME Backend (${HOST}) ==="
echo ""

run() {
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "${USER}@${HOST}" "$@"
}

FAIL=0

out=$(run "redis-cli ping 2>/dev/null" || true)
if echo "$out" | grep -q PONG; then
  echo "  OK: Redis PONG"
else
  echo "  FAIL: Redis PONG"; FAIL=1
fi

out=$(run "ss -tlnp 2>/dev/null | grep -E '127.0.0.1:6379|192.168.86.19:6379'" || true)
if echo "$out" | grep -q 6379; then
  echo "  OK: Redis listening on 127.0.0.1:6379 and 192.168.86.19:6379"
else
  echo "  FAIL: Redis bind"; FAIL=1
fi

out=$(run "ip -4 addr show eth0 2>/dev/null | grep 192.168.86.19" || true)
if [ -n "$out" ]; then
  echo "  OK: Static IP 192.168.86.19 on eth0"
else
  echo "  WARN: 192.168.86.19 not on eth0 (may use dhcpcd, reboot pending)"
fi

out=$(run "systemctl is-enabled redis-server 2>/dev/null" || true)
if [ "$out" = "enabled" ]; then
  echo "  OK: redis-server enabled"
else
  echo "  WARN: redis-server not enabled"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "Backend production checks passed."
else
  echo "Some checks failed."
  exit 1
fi
