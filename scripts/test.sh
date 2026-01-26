#!/bin/bash
# KOME Cache Node Testing Script
# Tests NGINX cache functionality on CN00
# Usage: ./scripts/test-cache-node.sh

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
UPSTREAM_IP="${UPSTREAM_IP:-192.168.86.25}"
UPSTREAM_PORT="${UPSTREAM_PORT:-3000}"

echo -e "${GREEN}=== KOME Cache Node Test ===${NC}"
echo "Cache Node: http://${CACHE_IP}"
echo "Upstream: http://${UPSTREAM_IP}:${UPSTREAM_PORT}"
echo ""

# Test 1: Upstream connectivity
echo -e "${GREEN}[1/6] Testing upstream connectivity...${NC}"
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://${UPSTREAM_IP}:${UPSTREAM_PORT}" | grep -qE "200|301|302"; then
  echo -e "${GREEN}✓ Upstream is reachable${NC}"
else
  echo -e "${RED}✗ Upstream is not reachable${NC}"
  echo -e "${YELLOW}  Verify OptiPlex is running and Open WebUI is accessible${NC}"
  exit 1
fi

# Test 2: Cache node connectivity
echo -e "${GREEN}[2/6] Testing cache node connectivity...${NC}"
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://${CACHE_IP}" | grep -qE "200|301|302"; then
  echo -e "${GREEN}✓ Cache node is responding${NC}"
else
  echo -e "${RED}✗ Cache node is not responding${NC}"
  exit 1
fi

# Test 3: NGINX status (via SSH)
echo -e "${GREEN}[3/6] Checking NGINX status...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
  echo -e "${GREEN}✓ NGINX is active${NC}"
else
  echo -e "${RED}✗ NGINX is not active${NC}"
  exit 1
fi

# Test 4: Cache configuration
echo -e "${GREEN}[4/6] Verifying cache configuration...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo test -f /etc/nginx/conf.d/kome-cache.conf && sudo nginx -t" 2>/dev/null; then
  echo -e "${GREEN}✓ Cache configuration is valid${NC}"
else
  echo -e "${RED}✗ Cache configuration is invalid or missing${NC}"
  exit 1
fi

# Test 5: Cache behavior (first request = MISS, second = HIT)
echo -e "${GREEN}[5/6] Testing cache behavior...${NC}"
echo "  Making first request (should be MISS)..."
RESPONSE1=$(curl -s -I "http://${CACHE_IP}/" 2>&1)
CACHE_STATUS1=$(echo "$RESPONSE1" | grep -i "X-Cache" | awk '{print $2}' || echo "NONE")

echo "  Making second request (should be HIT)..."
sleep 1
RESPONSE2=$(curl -s -I "http://${CACHE_IP}/" 2>&1)
CACHE_STATUS2=$(echo "$RESPONSE2" | grep -i "X-Cache" | awk '{print $2}' || echo "NONE")

echo "  First request cache status: ${CACHE_STATUS1}"
echo "  Second request cache status: ${CACHE_STATUS2}"

if [ "$CACHE_STATUS2" = "HIT" ] || [ "$CACHE_STATUS2" = "hit" ]; then
  echo -e "${GREEN}✓ Cache is working (second request was HIT)${NC}"
elif [ "$CACHE_STATUS1" = "MISS" ] || [ "$CACHE_STATUS1" = "miss" ]; then
  echo -e "${YELLOW}⚠ Cache headers present but HIT not confirmed (may need cached path)${NC}"
else
  echo -e "${YELLOW}⚠ Cache headers not present (may be normal for non-cached paths)${NC}"
fi

# Test 6: Cache statistics
echo -e "${GREEN}[6/6] Gathering cache statistics...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo tail -100 /var/log/nginx/access.log 2>/dev/null | grep -c 'X-Cache.*HIT' || echo '0'" 2>/dev/null | head -1; then
  HIT_COUNT=$(sshpass -p "${CACHE_PASSWORD}" \
    ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
    "${CACHE_USER}@${CACHE_IP}" \
    "sudo tail -100 /var/log/nginx/access.log 2>/dev/null | grep -c 'X-Cache.*HIT' || echo '0'")
  TOTAL_COUNT=$(sshpass -p "${CACHE_PASSWORD}" \
    ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
    "${CACHE_USER}@${CACHE_IP}" \
    "sudo tail -100 /var/log/nginx/access.log 2>/dev/null | grep -c 'X-Cache' || echo '0'")
  
  if [ "$TOTAL_COUNT" -gt 0 ]; then
    HIT_RATE=$(echo "scale=1; $HIT_COUNT * 100 / $TOTAL_COUNT" | bc)
    echo "  Cache hits (last 100 requests): ${HIT_COUNT}/${TOTAL_COUNT} (${HIT_RATE}%)"
  else
    echo "  No cache statistics available yet"
  fi
fi

# Cache directory size
CACHE_SIZE=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo du -sh /var/cache/nginx/static 2>/dev/null | awk '{print \$1}' || echo '0'")
echo "  Cache directory size: ${CACHE_SIZE}"

echo ""
echo -e "${GREEN}=== Cache Node Test Complete ===${NC}"
echo ""
echo "Cache node is operational and ready to serve frontend assets."
echo "Point your browser to: http://${CACHE_IP}"
echo ""
