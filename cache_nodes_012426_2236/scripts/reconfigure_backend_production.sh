#!/bin/bash
# OKOME Backend – live production reconfiguration for 192.168.86.19
# Plan: okome_two-node_cache_architecture_implementation
# Usage: sudo ./reconfigure_backend_production.sh [CONFIG_BASE]
# CONFIG_BASE: directory containing configs/ (default: script’s repo layout)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKEND_IP="192.168.86.19"
ROUTER="192.168.86.1"
DNS="192.168.86.1"
BACKEND_NETMASK="24"
REDIS_CONF_DEST="/etc/redis/redis.conf"
DHCPCD_CONF="/etc/dhcpcd.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIG_BASE="${1:-$REPO}"
CONFIGS="${CONFIG_BASE}/configs"
REDIS_CONF_SRC="${CONFIGS}/redis-backend/redis.conf"
SYSCTL_SRC="${CONFIGS}/sysctl-okome.conf"
JOURNALD_SRC="${CONFIGS}/journald-okome.conf"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Run with sudo${NC}"
  exit 1
fi

if [ ! -f "$REDIS_CONF_SRC" ]; then
  echo -e "${RED}Error: Redis config not found at ${REDIS_CONF_SRC}${NC}"
  exit 1
fi

echo -e "${GREEN}=== OKOME Backend – live production reconfig ===${NC}"
echo "Node: ${BACKEND_IP}"
echo ""

# ---- 1. Static IP (192.168.86.19) ----
echo -e "${GREEN}[1/7] Static IP ${BACKEND_IP}...${NC}"
STATIC_DONE=0
if command -v nmcli &>/dev/null && systemctl is-active NetworkManager &>/dev/null; then
  NM_CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: '$2=="eth0"{print $1; exit}')
  if [ -n "$NM_CONN" ]; then
    CUR=$(nmcli -g ipv4.addresses connection show "$NM_CONN" 2>/dev/null | cut -d/ -f1)
    if [ "$CUR" = "$BACKEND_IP" ]; then
      echo -e "${GREEN}  Already ${BACKEND_IP} via NetworkManager (${NM_CONN}).${NC}"
      STATIC_DONE=1
    else
      if nmcli connection modify "$NM_CONN" ipv4.addresses "${BACKEND_IP}/${BACKEND_NETMASK}" ipv4.gateway "$ROUTER" ipv4.dns "$DNS" ipv4.method manual 2>/dev/null; then
        nmcli connection up "$NM_CONN" 2>/dev/null && echo -e "${GREEN}  Applied ${BACKEND_IP} via NetworkManager.${NC}" || echo -e "${YELLOW}  Configured; run 'nmcli connection up \"${NM_CONN}\"' or reboot.${NC}"
        STATIC_DONE=1
      fi
    fi
  fi
fi
if [ "$STATIC_DONE" -eq 0 ] && [ -f "$DHCPCD_CONF" ]; then
  if grep -q "static ip_address=${BACKEND_IP}/" "$DHCPCD_CONF"; then
    echo -e "${GREEN}  Already in ${DHCPCD_CONF}. Reboot to apply.${NC}"
  elif grep -q "static ip_address=192.168.86." "$DHCPCD_CONF"; then
    sed -i "s|static ip_address=192.168.86.[0-9]*/[0-9]*|static ip_address=${BACKEND_IP}/${BACKEND_NETMASK}|g" "$DHCPCD_CONF"
    echo -e "${GREEN}  Updated ${DHCPCD_CONF}. Reboot to apply.${NC}"
  else
    cat >> "$DHCPCD_CONF" << EOF

# OKOME backend (nc01) – live production
interface eth0
static ip_address=${BACKEND_IP}/${BACKEND_NETMASK}
static routers=${ROUTER}
static domain_name_servers=${DNS}
EOF
    echo -e "${GREEN}  Added to ${DHCPCD_CONF}. Reboot to apply.${NC}"
  fi
  STATIC_DONE=1
fi
[ "$STATIC_DONE" -eq 0 ] && echo -e "${YELLOW}  Skip: no NetworkManager/dhcpcd. Configure manually.${NC}"

# ---- 2. Disable unnecessary services ----
echo -e "${GREEN}[2/7] Disable bluetooth, avahi...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true
echo -e "${GREEN}  Done.${NC}"

# ---- 3. Journald RAM-only ----
echo -e "${GREEN}[3/7] Journald RAM-only...${NC}"
JOURNALD_D="/etc/systemd/journald.conf.d"
mkdir -p "$JOURNALD_D"
if [ -f "$JOURNALD_SRC" ]; then
  cp "$JOURNALD_SRC" "$JOURNALD_D/okome.conf"
  systemctl restart systemd-journald 2>/dev/null || true
  echo -e "${GREEN}  Applied ${JOURNALD_SRC}.${NC}"
elif ! grep -q "Storage=volatile" /etc/systemd/journald.conf 2>/dev/null; then
  grep -q "^#Storage=" /etc/systemd/journald.conf && sed -i 's/^#Storage=.*/Storage=volatile/' /etc/systemd/journald.conf || true
  grep -q "^#RuntimeMaxUse=" /etc/systemd/journald.conf && sed -i 's/^#RuntimeMaxUse=.*/RuntimeMaxUse=50M/' /etc/systemd/journald.conf || true
  systemctl restart systemd-journald 2>/dev/null || true
  echo -e "${GREEN}  Inline volatile + 50M.${NC}"
else
  echo -e "${GREEN}  Already configured.${NC}"
fi

# ---- 4. Sysctl ----
echo -e "${GREEN}[4/7] Sysctl production tweaks...${NC}"
if [ -f "$SYSCTL_SRC" ]; then
  cp "$SYSCTL_SRC" /etc/sysctl.d/okome.conf
  sysctl -p /etc/sysctl.d/okome.conf 2>/dev/null || true
  echo -e "${GREEN}  Applied ${SYSCTL_SRC}.${NC}"
else
  echo -e "${YELLOW}  Skip: ${SYSCTL_SRC} not found.${NC}"
fi

# ---- 5. Redis production config ----
echo -e "${GREEN}[5/7] Redis production config...${NC}"
cp "$REDIS_CONF_SRC" "$REDIS_CONF_DEST"
grep -q "192.168.86.19" "$REDIS_CONF_DEST" || sed -i 's/^bind .*/bind 127.0.0.1 192.168.86.19/' "$REDIS_CONF_DEST"
chown redis:redis "$REDIS_CONF_DEST" 2>/dev/null || true
systemctl enable redis-server 2>/dev/null || true
systemctl restart redis-server
echo -e "${GREEN}  Deployed and restarted.${NC}"

# ---- 6. Logrotate for Redis ----
echo -e "${GREEN}[6/7] Logrotate Redis...${NC}"
cat > /etc/logrotate.d/redis-okome << 'LR'
/var/log/redis/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 redis redis
    postrotate
        [ -f /var/run/redis/redis-server.pid ] && kill -USR1 $(cat /var/run/redis/redis-server.pid) 2>/dev/null || true
    endscript
}
LR
echo -e "${GREEN}  Done.${NC}"

# ---- 7. Verify ----
echo -e "${GREEN}[7/7] Verify...${NC}"
sleep 2
if redis-cli ping 2>/dev/null | grep -q PONG; then
  echo -e "${GREEN}  Redis PONG.${NC}"
else
  echo -e "${RED}  Redis ping failed.${NC}"
  exit 1
fi
BIND_CHECK=$(ss -tlnp 2>/dev/null | grep -E "127.0.0.1:6379|192.168.86.19:6379" || true)
if [ -n "$BIND_CHECK" ]; then
  echo -e "${GREEN}  Listening on 127.0.0.1:6379 and 192.168.86.19:6379.${NC}"
else
  echo -e "${YELLOW}  Bind check inconclusive (ss).${NC}"
fi

echo ""
echo -e "${GREEN}=== Backend live production ready ===${NC}"
echo "  Redis: 127.0.0.1:6379, ${BACKEND_IP}:6379"
echo "  Static IP: ${BACKEND_IP}. Reboot if using dhcpcd."
echo "  Verify: ./verify_backend.sh (or redis-cli ping)"
echo ""
