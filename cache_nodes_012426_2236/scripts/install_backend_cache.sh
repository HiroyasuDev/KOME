#!/usr/bin/env bash
# Install Backend Cache Node (Redis)
# Node: 192.168.86.19
# Usage: sudo ./install_backend_cache.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== OKOME Backend Cache Node Installation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Step 1: Install Redis
echo -e "${GREEN}[1/3] Installing Redis...${NC}"
apt-get update
apt-get install -y redis-server

# Step 2: Backup and install configuration
echo -e "${GREEN}[2/3] Installing Redis configuration...${NC}"
if [ -f "/etc/redis/redis.conf.backup" ]; then
  echo "Backup already exists, skipping..."
else
  cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
  echo "Backup created: /etc/redis/redis.conf.backup"
fi

# Note: Configuration file should be copied from cache_nodes_012426_2236/configs/redis-backend/redis.conf
# to /etc/redis/redis.conf
echo -e "${YELLOW}Please copy redis.conf to /etc/redis/redis.conf${NC}"

# Step 3: Restart Redis
echo -e "${GREEN}[3/3] Restarting Redis...${NC}"
systemctl restart redis-server
systemctl enable redis-server

# Verify
if redis-cli ping > /dev/null 2>&1; then
  echo -e "${GREEN}Redis is running${NC}"
else
  echo -e "${RED}Error: Redis is not responding${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo "Backend cache node is ready at: 192.168.86.19:6379"
echo ""
