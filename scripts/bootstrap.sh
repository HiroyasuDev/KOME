#!/bin/bash
# KOME Cache Node Bootstrap Script
# One-command setup for Raspberry Pi cache node
# Usage: sudo ./scripts/cache-node-bootstrap.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CACHE_IP="192.168.86.20"
CORE_IP="192.168.86.25"
CORE_PORT="3000"  # Open WebUI port
NGINX_CACHE_DIR="/var/cache/nginx/static"
NGINX_CONFIG="/etc/nginx/conf.d/kome-cache.conf"

echo -e "${GREEN}=== KOME Cache Node Bootstrap ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Detect if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
  echo -e "${YELLOW}Warning: This script is designed for Raspberry Pi${NC}"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Step 1: System update and base packages
echo -e "${GREEN}[1/8] Updating system and installing base packages...${NC}"
# Skip full-upgrade to save time and reduce connection risk
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx logrotate curl

# Step 2: Disable unnecessary services
echo -e "${GREEN}[2/8] Disabling unnecessary services...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true

# Step 3: Configure journald for minimal writes
echo -e "${GREEN}[3/8] Configuring systemd journal for minimal writes...${NC}"
if ! grep -q "Storage=volatile" /etc/systemd/journald.conf; then
  sed -i 's/#Storage=auto/Storage=volatile/' /etc/systemd/journald.conf
  sed -i 's/#RuntimeMaxUse=/RuntimeMaxUse=50M/' /etc/systemd/journald.conf
  systemctl restart systemd-journald
  echo -e "${GREEN}Journal configured for volatile storage${NC}"
else
  echo -e "${GREEN}Journal already configured${NC}"
fi

# Step 4: Configure log rotation
echo -e "${GREEN}[4/8] Configuring log rotation...${NC}"
cat > /etc/logrotate.d/nginx-kome <<EOF
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
        [ -f /var/run/nginx.pid ] && kill -USR1 \$(cat /var/run/nginx.pid)
    endscript
}
EOF
echo -e "${GREEN}Log rotation configured${NC}"

# Step 5: Create tmpfs cache mount (optional but recommended)
echo -e "${GREEN}[5/8] Configuring tmpfs cache mount...${NC}"
if ! grep -q "/var/cache/nginx tmpfs" /etc/fstab; then
  echo "tmpfs /var/cache/nginx tmpfs size=256m,noatime 0 0" >> /etc/fstab
  mkdir -p /var/cache/nginx
  mount -a
  echo -e "${GREEN}tmpfs cache mounted${NC}"
else
  echo -e "${GREEN}tmpfs cache already configured${NC}"
fi

# Step 6: Create NGINX cache directory
echo -e "${GREEN}[6/8] Creating NGINX cache directory...${NC}"
mkdir -p "${NGINX_CACHE_DIR}"
chown -R www-data:www-data /var/cache/nginx
chmod 755 /var/cache/nginx

# Step 7: Install NGINX configuration
echo -e "${GREEN}[7/8] Installing NGINX configuration...${NC}"
cat > "${NGINX_CONFIG}" <<'NGINX_EOF'
# KOME Frontend Cache Node Configuration
# This file is managed by bootstrap.sh
# Do not edit manually - regenerate with bootstrap script

upstream kome_core {
    server 192.168.86.25:3000 max_fails=3 fail_timeout=10s;
    keepalive 32;
}

proxy_cache_path /var/cache/nginx/static
    levels=1:2
    keys_zone=STATIC:50m
    inactive=24h
    max_size=1g
    use_temp_path=off;

limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

server {
    listen 80;
    server_name okome.local;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;

    # ---- Explicit cache allowlist ----
    location ~ ^/(assets|ui-schema|version)/ {
        proxy_pass http://kome_core;
        proxy_cache STATIC;
        proxy_cache_valid 200 24h;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        add_header X-Cache $upstream_cache_status;
        add_header X-Cache-Key $scheme$proxy_host$request_uri;
        
        # Proxy headers
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
    }

    # ---- Everything else (uncached + protected) ----
    location / {
        limit_req zone=api_limit burst=20 nodelay;
        proxy_pass http://kome_core;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
}
NGINX_EOF

# Replace placeholder IPs in config
sed -i "s/192.168.86.25:3000/${CORE_IP}:${CORE_PORT}/g" "${NGINX_CONFIG}"

# Step 8: Test and start NGINX
echo -e "${GREEN}[8/8] Testing NGINX configuration...${NC}"
if nginx -t; then
  systemctl enable nginx
  systemctl restart nginx
  echo -e "${GREEN}NGINX started successfully${NC}"
else
  echo -e "${RED}Error: NGINX configuration test failed${NC}"
  exit 1
fi

# Verification
echo ""
echo -e "${GREEN}=== Bootstrap Complete ===${NC}"
echo ""
echo "Verification steps:"
echo "1. Test upstream: curl -I http://${CORE_IP}:${CORE_PORT}"
echo "2. Test cache: curl -I http://${CACHE_IP}/assets/app.js"
echo "3. Check logs: tail -f /var/log/nginx/access.log"
echo ""
echo "Cache node is ready at: http://${CACHE_IP}"
echo ""
