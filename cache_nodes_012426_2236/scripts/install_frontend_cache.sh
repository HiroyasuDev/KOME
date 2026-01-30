#!/usr/bin/env bash
# Install Frontend Cache Node (Nginx)
# Node: 192.168.86.20
# Usage: sudo ./install_frontend_cache.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== OKOME Frontend Cache Node Installation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Step 1: Install Nginx
echo -e "${GREEN}[1/4] Installing Nginx...${NC}"
apt-get update
apt-get install -y nginx

# Step 2: Create cache directory
echo -e "${GREEN}[2/4] Creating cache directory...${NC}"
mkdir -p /var/cache/nginx/okome
chown -R www-data:www-data /var/cache/nginx

# Step 3: Install configuration
echo -e "${GREEN}[3/4] Installing Nginx configuration...${NC}"
# Note: Configuration file should be copied from cache_nodes_012426_2236/configs/nginx-frontend/okome-frontend.conf
# to /etc/nginx/sites-available/okome-frontend

if [ -f "/etc/nginx/sites-available/okome-frontend" ]; then
  echo "Configuration already exists, skipping..."
else
  echo -e "${YELLOW}Please copy okome-frontend.conf to /etc/nginx/sites-available/okome-frontend${NC}"
  echo "Then run: sudo ln -s /etc/nginx/sites-available/okome-frontend /etc/nginx/sites-enabled/"
fi

# Step 4: Test and start
echo -e "${GREEN}[4/4] Testing Nginx configuration...${NC}"
if nginx -t; then
  systemctl enable nginx
  systemctl restart nginx
  echo -e "${GREEN}Nginx started successfully${NC}"
else
  echo -e "${RED}Error: Nginx configuration test failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo "Frontend cache node is ready at: http://192.168.86.20"
echo ""
