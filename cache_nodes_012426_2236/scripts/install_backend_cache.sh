#!/bin/bash
# OKOME Backend Cache - Install Redis on nc01.local (192.168.86.19)
# Plan: okome_two-node_cache_architecture_implementation
# Usage: sudo ./install_backend_cache.sh [CONFIG_DIR]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKEND_IP="192.168.86.19"
BACKEND_NETMASK="24"
ROUTER="192.168.86.1"
DNS="192.168.86.1"
REDIS_CONF_DEST="/etc/redis/redis.conf"
DHCPCD_CONF="/etc/dhcpcd.conf"

# Config directory: first arg, or repo layout relative to script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${1:-}"
if [ -z "$CONFIG_DIR" ]; then
  CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs/redis-backend"
fi
REDIS_CONF_SRC="${CONFIG_DIR}/redis.conf"

if [ ! -f "$REDIS_CONF_SRC" ]; then
  echo -e "${RED}Error: Redis config not found at ${REDIS_CONF_SRC}${NC}"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Run with sudo${NC}"
  exit 1
fi

echo -e "${GREEN}=== OKOME Backend Cache Install ===${NC}"
echo "Backend IP: ${BACKEND_IP}"
echo ""

# ---- Static IP (192.168.86.19) ----
echo -e "${GREEN}[1/5] Configuring static IP ${BACKEND_IP}...${NC}"
STATIC_IP_DONE=0

# Prefer NetworkManager (nmcli) when available and managing eth0
if command -v nmcli &>/dev/null && systemctl is-active NetworkManager &>/dev/null; then
  NM_CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: '$2=="eth0"{print $1; exit}')
  if [ -n "$NM_CONN" ]; then
    CUR_IP=$(nmcli -g ipv4.addresses connection show "$NM_CONN" 2>/dev/null | cut -d/ -f1)
    if [ "$CUR_IP" = "$BACKEND_IP" ]; then
      echo -e "${GREEN}Static IP ${BACKEND_IP} already set via NetworkManager (${NM_CONN}).${NC}"
      STATIC_IP_DONE=1
    else
      if nmcli connection modify "$NM_CONN" ipv4.addresses "${BACKEND_IP}/${BACKEND_NETMASK}" ipv4.gateway "$ROUTER" ipv4.dns "$DNS" ipv4.method manual 2>/dev/null; then
        nmcli connection up "$NM_CONN" 2>/dev/null && echo -e "${GREEN}Static IP ${BACKEND_IP} applied via NetworkManager (${NM_CONN}).${NC}" || echo -e "${GREEN}Static IP ${BACKEND_IP} configured; run 'nmcli connection up \"${NM_CONN}\"' or reboot to apply.${NC}"
        STATIC_IP_DONE=1
      fi
    fi
  fi
fi

# Fall back to dhcpcd (e.g. Raspberry Pi OS without NetworkManager)
if [ "$STATIC_IP_DONE" -eq 0 ] && [ -f "$DHCPCD_CONF" ]; then
  if grep -q "static ip_address=${BACKEND_IP}/" "$DHCPCD_CONF"; then
    echo -e "${GREEN}Static IP ${BACKEND_IP} already in ${DHCPCD_CONF}${NC}"
  elif grep -q "static ip_address=192.168.86." "$DHCPCD_CONF"; then
    sed -i "s|static ip_address=192.168.86.[0-9]*/[0-9]*|static ip_address=${BACKEND_IP}/${BACKEND_NETMASK}|g" "$DHCPCD_CONF"
    echo -e "${GREEN}Updated static IP to ${BACKEND_IP} in ${DHCPCD_CONF}. Reboot to apply.${NC}"
  else
    cat >> "$DHCPCD_CONF" << EOF

# OKOME backend cache node (nc01.local)
interface eth0
static ip_address=${BACKEND_IP}/${BACKEND_NETMASK}
static routers=${ROUTER}
static domain_name_servers=${DNS}
EOF
    echo -e "${GREEN}Static IP ${BACKEND_IP} added to ${DHCPCD_CONF}. Reboot to apply.${NC}"
  fi
  STATIC_IP_DONE=1
fi

if [ "$STATIC_IP_DONE" -eq 0 ]; then
  echo -e "${YELLOW}Warning: Neither NetworkManager nor ${DHCPCD_CONF} available; skipping static IP. Configure manually.${NC}"
fi

# ---- Install Redis ----
echo -e "${GREEN}[2/5] Installing Redis...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server

# ---- Deploy Redis config ----
echo -e "${GREEN}[3/5] Deploying Redis config...${NC}"
cp "$REDIS_CONF_SRC" "$REDIS_CONF_DEST"
# Ensure bind includes node IP (use 192.168.86.19 per plan)
if ! grep -q "192.168.86.19" "$REDIS_CONF_DEST"; then
  sed -i 's/^bind .*/bind 127.0.0.1 192.168.86.19/' "$REDIS_CONF_DEST"
fi
chown redis:redis "$REDIS_CONF_DEST" 2>/dev/null || true

# ---- Enable and start Redis ----
echo -e "${GREEN}[4/5] Enabling and starting Redis...${NC}"
systemctl enable redis-server
systemctl restart redis-server

# ---- Verify ----
echo -e "${GREEN}[5/5] Verifying...${NC}"
sleep 2
if redis-cli ping | grep -q PONG; then
  echo -e "${GREEN}Redis is running.${NC}"
else
  echo -e "${RED}Redis ping failed. Check: sudo systemctl status redis-server${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}=== Backend cache ready ===${NC}"
echo "  Redis: 127.0.0.1:6379 and ${BACKEND_IP}:6379"
echo "  Static IP: ${BACKEND_IP} (eth0). Reboot to apply if using dhcpcd."
echo "  Check: redis-cli ping"
echo ""
