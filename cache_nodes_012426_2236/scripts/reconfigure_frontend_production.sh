#!/bin/bash
# OKOME Frontend – live production reconfiguration for 192.168.86.20 (CN00)
# Plan: okome_two-node_cache_architecture_implementation
# Usage: sudo ./reconfigure_frontend_production.sh [CONFIG_BASE]
# CONFIG_BASE: directory containing configs/ (default: script's repo layout; or REMOTE_BASE when deployed)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FRONTEND_IP="192.168.86.20"
ROUTER="192.168.86.1"
DNS="192.168.86.1"
FRONTEND_NETMASK="24"
DHCPCD_CONF="/etc/dhcpcd.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIG_BASE="${1:-$REPO}"
CONFIGS="${CONFIG_BASE}/configs"
SYSCTL_SRC="${CONFIGS}/sysctl-okome.conf"
JOURNALD_SRC="${CONFIGS}/journald-okome.conf"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Run with sudo${NC}"
  exit 1
fi

echo -e "${GREEN}=== OKOME Frontend – live production reconfig ===${NC}"
echo "Node: ${FRONTEND_IP} (CN00)"
echo ""

# ---- 1. Static IP (192.168.86.20) ----
echo -e "${GREEN}[1/5] Static IP ${FRONTEND_IP}...${NC}"
STATIC_DONE=0
if command -v nmcli &>/dev/null && systemctl is-active NetworkManager &>/dev/null; then
  NM_CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: '$2=="eth0"{print $1; exit}')
  if [ -n "$NM_CONN" ]; then
    CUR=$(nmcli -g ipv4.addresses connection show "$NM_CONN" 2>/dev/null | cut -d/ -f1)
    if [ "$CUR" = "$FRONTEND_IP" ]; then
      echo -e "${GREEN}  Already ${FRONTEND_IP} via NetworkManager (${NM_CONN}).${NC}"
      STATIC_DONE=1
    else
      if nmcli connection modify "$NM_CONN" ipv4.addresses "${FRONTEND_IP}/${FRONTEND_NETMASK}" ipv4.gateway "$ROUTER" ipv4.dns "$DNS" ipv4.method manual 2>/dev/null; then
        nmcli connection up "$NM_CONN" 2>/dev/null && echo -e "${GREEN}  Applied ${FRONTEND_IP} via NetworkManager.${NC}" || echo -e "${YELLOW}  Configured; run 'nmcli connection up \"${NM_CONN}\"' or reboot.${NC}"
        STATIC_DONE=1
      fi
    fi
  fi
fi
if [ "$STATIC_DONE" -eq 0 ] && [ -f "$DHCPCD_CONF" ]; then
  if grep -q "static ip_address=${FRONTEND_IP}/" "$DHCPCD_CONF"; then
    echo -e "${GREEN}  Already in ${DHCPCD_CONF}. Reboot to apply.${NC}"
  elif grep -q "static ip_address=192.168.86." "$DHCPCD_CONF"; then
    sed -i "s|static ip_address=192.168.86.[0-9]*/[0-9]*|static ip_address=${FRONTEND_IP}/${FRONTEND_NETMASK}|g" "$DHCPCD_CONF"
    echo -e "${GREEN}  Updated ${DHCPCD_CONF}. Reboot to apply.${NC}"
  else
    cat >> "$DHCPCD_CONF" << EOF

# OKOME frontend (CN00) – live production
interface eth0
static ip_address=${FRONTEND_IP}/${FRONTEND_NETMASK}
static routers=${ROUTER}
static domain_name_servers=${DNS}
EOF
    echo -e "${GREEN}  Added to ${DHCPCD_CONF}. Reboot to apply.${NC}"
  fi
  STATIC_DONE=1
fi
[ "$STATIC_DONE" -eq 0 ] && echo -e "${YELLOW}  Skip: no NetworkManager/dhcpcd. Configure manually.${NC}"

# ---- 2. Disable unnecessary services ----
echo -e "${GREEN}[2/5] Disable bluetooth, avahi...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true
echo -e "${GREEN}  Done.${NC}"

# ---- 3. Journald RAM-only ----
echo -e "${GREEN}[3/5] Journald RAM-only...${NC}"
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
echo -e "${GREEN}[4/5] Sysctl production tweaks...${NC}"
if [ -f "$SYSCTL_SRC" ]; then
  cp "$SYSCTL_SRC" /etc/sysctl.d/okome.conf
  sysctl -p /etc/sysctl.d/okome.conf 2>/dev/null || true
  echo -e "${GREEN}  Applied ${SYSCTL_SRC}.${NC}"
else
  echo -e "${YELLOW}  Skip: ${SYSCTL_SRC} not found.${NC}"
fi

# ---- 5. Hostname CN00 ----
echo -e "${GREEN}[5/5] Hostname CN00...${NC}"
hostnamectl set-hostname CN00 2>/dev/null || true
echo -e "${GREEN}  Done.${NC}"

echo ""
echo -e "${GREEN}=== Frontend live production ready ===${NC}"
echo "  Static IP: ${FRONTEND_IP}. Reboot if using dhcpcd."
echo "  Verify: ./verify_frontend.sh (or curl -I http://${FRONTEND_IP}/)"
echo ""
