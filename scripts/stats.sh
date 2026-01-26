#!/bin/bash
# KOME Cache Node Statistics Script
# Shows cache performance statistics
# Usage: ./scripts/cache-node-stats.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CACHE_IP="${CACHE_IP:-192.168.86.20}"
CACHE_USER="${CACHE_USER:-ncadmin}"
CACHE_PORT="${CACHE_PORT:-22}"
CACHE_PASSWORD="${CACHE_PASSWORD:-usshopper}"
LOG_LINES="${LOG_LINES:-1000}"

echo -e "${GREEN}=== KOME Cache Node Statistics ===${NC}"
echo "Cache Node: ${CACHE_IP}"
echo "Analyzing last ${LOG_LINES} requests"
echo ""

# Get cache statistics from logs
STATS=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo tail -${LOG_LINES} /var/log/nginx/access.log 2>/dev/null | \
   grep 'X-Cache' | \
   awk '{print \$NF}' | \
   sort | uniq -c" 2>/dev/null || echo "")

if [ -z "$STATS" ]; then
  echo -e "${YELLOW}No cache statistics available yet${NC}"
  echo "Make some requests to the cache node to generate statistics."
  exit 0
fi

# Parse statistics
HIT_COUNT=$(echo "$STATS" | grep -i "HIT" | awk '{sum+=$1} END {print sum+0}')
MISS_COUNT=$(echo "$STATS" | grep -i "MISS" | awk '{sum+=$1} END {print sum+0}')
BYPASS_COUNT=$(echo "$STATS" | grep -i "BYPASS" | awk '{sum+=$1} END {print sum+0}')
TOTAL=$((HIT_COUNT + MISS_COUNT + BYPASS_COUNT))

if [ "$TOTAL" -eq 0 ]; then
  echo -e "${YELLOW}No cacheable requests found in logs${NC}"
  exit 0
fi

# Calculate hit rate
if [ "$TOTAL" -gt 0 ]; then
  HIT_RATE=$(echo "scale=2; $HIT_COUNT * 100 / $TOTAL" | bc)
else
  HIT_RATE=0
fi

# Display statistics
echo "Cache Statistics:"
echo "  Total cacheable requests: ${TOTAL}"
echo "  Cache hits: ${HIT_COUNT}"
echo "  Cache misses: ${MISS_COUNT}"
if [ "$BYPASS_COUNT" -gt 0 ]; then
  echo "  Cache bypasses: ${BYPASS_COUNT}"
fi
echo "  Hit rate: ${HIT_RATE}%"
echo ""

# Cache directory info
echo "Cache Storage:"
CACHE_SIZE=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo du -sh /var/cache/nginx/static 2>/dev/null | awk '{print \$1}' || echo '0'")
CACHE_FILES=$(sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo find /var/cache/nginx/static -type f 2>/dev/null | wc -l || echo '0'")
echo "  Cache size: ${CACHE_SIZE}"
echo "  Cached files: ${CACHE_FILES}"
echo ""

# Performance assessment
if (( $(echo "$HIT_RATE >= 80" | bc -l) )); then
  echo -e "${GREEN}✓ Excellent cache performance (hit rate >= 80%)${NC}"
elif (( $(echo "$HIT_RATE >= 50" | bc -l) )); then
  echo -e "${GREEN}✓ Good cache performance (hit rate >= 50%)${NC}"
elif [ "$TOTAL" -lt 10 ]; then
  echo -e "${YELLOW}⚠ Insufficient data (need more requests)${NC}"
else
  echo -e "${YELLOW}⚠ Cache performance below target (hit rate < 50%)${NC}"
  echo "  Consider:"
  echo "    - Verify cache paths are being requested (/assets/, /ui-schema/, /version/)"
  echo "    - Check if frontend uses content-hashed filenames"
  echo "    - Review cache TTL settings"
fi

echo ""
