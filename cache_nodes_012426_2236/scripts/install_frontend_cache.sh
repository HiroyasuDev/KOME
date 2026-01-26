#!/bin/bash
# OKOME Frontend Cache – Install Nginx on 192.168.86.20 (CN00)
# Plan: okome_two-node_cache_architecture_implementation
# Usage: sudo ./install_frontend_cache.sh [CONFIG_DIR]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FRONTEND_IP="192.168.86.20"
ORCHESTRATOR="192.168.86.25:8000"
CACHE_PATH="/var/cache/nginx/okome"
NGINX_CONF_D="/etc/nginx/conf.d"
NGINX_CONF_DEST="${NGINX_CONF_D}/okome-frontend.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
CONFIG_BASE="${1:-$REPO}"
CONFIGS="${CONFIG_BASE}/configs"
NGINX_CONF_SRC="${CONFIGS}/nginx-frontend/okome-frontend.conf"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Run with sudo${NC}"
  exit 1
fi

[ ! -f "$NGINX_CONF_SRC" ] && { echo -e "${RED}Error: ${NGINX_CONF_SRC} not found${NC}"; exit 1; }

echo -e "${GREEN}=== OKOME Frontend Cache Install ===${NC}"
echo "Frontend: ${FRONTEND_IP}  Upstream: ${ORCHESTRATOR}"
echo ""

echo -e "${GREEN}[1/5] Disable bluetooth, avahi...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true

echo -e "${GREEN}[2/5] Install Nginx, logrotate...${NC}"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx logrotate curl

echo -e "${GREEN}[3/5] Create cache dir ${CACHE_PATH}...${NC}"
mkdir -p "$CACHE_PATH"
chown -R www-data:www-data /var/cache/nginx
chmod 755 /var/cache/nginx

echo -e "${GREEN}[4/5] Deploy Nginx config...${NC}"
# Remove old OKOME configs to avoid conflicts
rm -f "${NGINX_CONF_D}/kome-cache.conf" 2>/dev/null || true
rm -f "${NGINX_CONF_D}/default" 2>/dev/null || true
cp "$NGINX_CONF_SRC" "$NGINX_CONF_DEST"

echo -e "${GREEN}[5/5] Logrotate, enable, start...${NC}"
cat > /etc/logrotate.d/nginx-okome << 'LR'
/var/log/nginx/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 $(cat /var/run/nginx.pid)
    endscript
}
LR
nginx -t
systemctl enable nginx
systemctl restart nginx

echo ""
echo -e "${GREEN}=== Frontend cache ready ===${NC}"
echo "  Nginx: ${FRONTEND_IP}:80  Upstream: ${ORCHESTRATOR}"
echo "  Cache: ${CACHE_PATH} (2GB)"
echo "  Test: curl -I http://${FRONTEND_IP}/assets/"
echo ""
