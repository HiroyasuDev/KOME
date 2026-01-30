#!/usr/bin/env bash
# OKOME Chaos Testing Framework
# Safe failure injection for validation
# Usage: ./okome-chaos.sh <mode> [duration_seconds]
#
# Modes:
#   nginx-stop | redis-stop | vip-failover | upstream-drop | reboot-frontend | reboot-backend

set -euo pipefail

SSH_KEY="${SSH_KEY:-$HOME/.ssh/okome_cache}"
USER="${USER:-pi}"

FRONTEND="192.168.86.20"
BACKEND="192.168.86.19"
VIP="192.168.86.18"

MODE="${1:-}"
DURATION="${2:-15}"

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <mode> [duration_seconds]"
  echo ""
  echo "Modes:"
  echo "  nginx-stop      - Stop Nginx temporarily"
  echo "  redis-stop      - Stop Redis temporarily"
  echo "  vip-failover    - Force VIP failover"
  echo "  upstream-drop   - Block packets to orchestrator"
  echo "  reboot-frontend - Reboot frontend node"
  echo "  reboot-backend  - Reboot backend node"
  exit 1
fi

run() {
  local host="$1"
  shift
  ssh -i "$SSH_KEY" "$USER@$host" "$@"
}

require_enabled() {
  local host="$1"
  if ! run "$host" "test -f /etc/okome/CHAOS_ENABLE" 2>/dev/null; then
    echo "ERROR: CHAOS not enabled on $host"
    echo "Enable with: ssh $host 'sudo mkdir -p /etc/okome && echo test | sudo tee /etc/okome/CHAOS_ENABLE'"
    exit 2
  fi
}

case "$MODE" in
  nginx-stop)
    require_enabled "$FRONTEND"
    echo "Stopping Nginx on $FRONTEND for ${DURATION}s..."
    run "$FRONTEND" "sudo systemctl stop nginx; sleep $DURATION; sudo systemctl start nginx"
    ;;
  redis-stop)
    require_enabled "$BACKEND"
    echo "Stopping Redis on $BACKEND for ${DURATION}s..."
    run "$BACKEND" "sudo systemctl stop redis-server; sleep $DURATION; sudo systemctl start redis-server"
    ;;
  vip-failover)
    require_enabled "$FRONTEND"
    echo "Stopping keepalived on $FRONTEND for ${DURATION}s (should trigger failover)..."
    run "$FRONTEND" "sudo systemctl stop keepalived; sleep $DURATION; sudo systemctl start keepalived"
    ;;
  upstream-drop)
    require_enabled "$FRONTEND"
    echo "Blocking packets to orchestrator from $FRONTEND for ${DURATION}s..."
    run "$FRONTEND" "sudo iptables -I OUTPUT -d 192.168.86.25 -p tcp --dport 8000 -j REJECT; sleep $DURATION; sudo iptables -D OUTPUT -d 192.168.86.25 -p tcp --dport 8000 -j REJECT 2>/dev/null || sudo iptables -F OUTPUT"
    ;;
  reboot-frontend)
    require_enabled "$FRONTEND"
    echo "Rebooting $FRONTEND..."
    run "$FRONTEND" "sudo reboot" || true
    ;;
  reboot-backend)
    require_enabled "$BACKEND"
    echo "Rebooting $BACKEND..."
    run "$BACKEND" "sudo reboot" || true
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac

echo ""
echo "Chaos action complete. Verifying..."

# Basic verify: VIP responds (if used), frontend headers, backend redis pong
sleep 2
curl -fsSI "http://$VIP/" 2>/dev/null | grep -i "HTTP\|X-Cache\|X-OKOME" || echo "VIP check failed"
redis-cli -h "$BACKEND" ping 2>/dev/null || echo "Redis check failed"

echo "Verification complete."
