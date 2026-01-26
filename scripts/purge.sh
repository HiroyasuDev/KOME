#!/bin/bash
# KOME Cache Node Purge Script
# Clears the NGINX cache on CN00
# Usage: ./scripts/cache-node-purge.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CACHE_IP="${CACHE_IP:-192.168.86.20}"
CACHE_USER="${CACHE_USER:-ncadmin}"
CACHE_PORT="${CACHE_PORT:-22}"
CACHE_PASSWORD="${CACHE_PASSWORD:-usshopper}"

echo -e "${GREEN}=== KOME Cache Node Purge ===${NC}"
echo "Cache Node: ${CACHE_USER}@${CACHE_IP}:${CACHE_PORT}"
echo ""

# Confirm action
read -p "Clear all cached content? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Purge cancelled."
  exit 0
fi

# Get cache size before purge
echo -e "${YELLOW}Checking cache size...${NC}"
BEFORE_SIZE=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo du -sh /var/cache/nginx/static 2>/dev/null | awk '{print \$1}' || echo '0'")
echo "Current cache size: ${BEFORE_SIZE}"

# Purge cache
echo -e "${YELLOW}Purging cache...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo rm -rf /var/cache/nginx/static/* && sudo systemctl reload nginx" 2>/dev/null; then
  echo -e "${GREEN}✓ Cache purged successfully${NC}"
else
  echo -e "${RED}✗ Failed to purge cache${NC}"
  exit 1
fi

# Verify cache is empty
AFTER_SIZE=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo du -sh /var/cache/nginx/static 2>/dev/null | awk '{print \$1}' || echo '0'")
echo "Cache size after purge: ${AFTER_SIZE}"

echo ""
echo -e "${GREEN}=== Cache Purge Complete ===${NC}"
echo "Cache will rebuild as new requests come in."
echo ""
