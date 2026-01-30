#!/usr/bin/env bash
# OKOME Cache Nodes - One-Command Validation
# Usage: ./okome-validate.sh
#
# Validates both frontend and backend cache nodes

set -euo pipefail

SSH_KEY="${SSH_KEY:-$HOME/.ssh/okome_cache}"
USER="${USER:-pi}"

NODES=(
  "frontend 192.168.86.20"
  "backend  192.168.86.19"
)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

for node in "${NODES[@]}"; do
  set -- $node
  ROLE=$1
  IP=$2

  echo "=============================="
  echo -e "${YELLOW}OKOME $ROLE NODE ($IP)${NC}"
  echo "=============================="

  if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$USER@$IP" exit 2>/dev/null; then
    ssh -i "$SSH_KEY" "$USER@$IP" <<'EOF'
      echo "HOST: $(hostname)"
      echo "UPTIME:"
      uptime

      echo ""
      echo "MEMORY:"
      free -h

      echo ""
      echo "DISK:"
      df -h /

      echo ""
      echo "RUNNING SERVICES:"
      systemctl is-active ssh && echo "  ✓ SSH" || echo "  ✗ SSH"
      systemctl is-active node-exporter && echo "  ✓ node-exporter" || echo "  - node-exporter (optional)"
      systemctl is-active nginx && echo "  ✓ nginx" || echo "  - nginx (frontend only)"
      systemctl is-active redis-server && echo "  ✓ redis-server" || echo "  - redis-server (backend only)"
      systemctl is-active keepalived && echo "  ✓ keepalived" || echo "  - keepalived (optional)"
EOF
  else
    echo -e "${RED}✗ Cannot connect via SSH${NC}"
  fi

  if [[ "$ROLE" == "frontend" ]]; then
    echo ""
    echo "CACHE HEADER CHECK:"
    if curl -fsSI "http://$IP/" >/dev/null 2>&1; then
      curl -sI "http://$IP/" | grep -i "X-Cache\|X-OKOME\|HTTP" || true
    else
      echo -e "${RED}✗ Frontend not responding${NC}"
    fi
  fi

  if [[ "$ROLE" == "backend" ]]; then
    echo ""
    echo "REDIS CHECK:"
    if redis-cli -h "$IP" ping >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Redis responding${NC}"
      redis-cli -h "$IP" info memory | grep -E "used_memory_human|maxmemory_human" || true
    else
      echo -e "${RED}✗ Redis not responding${NC}"
    fi
  fi

  echo ""
done

# VIP Check
echo "=============================="
echo -e "${YELLOW}VIP CHECK (192.168.86.18)${NC}"
echo "=============================="
if curl -fsSI "http://192.168.86.18/" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ VIP is responding${NC}"
  curl -sI "http://192.168.86.18/" | grep -i "HTTP\|X-OKOME" || true
else
  echo -e "${RED}✗ VIP is not responding${NC}"
fi

echo ""
echo "=============================="
echo "Validation complete"
echo "=============================="
