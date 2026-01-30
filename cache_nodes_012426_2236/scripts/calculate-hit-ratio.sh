#!/usr/bin/env bash
# Calculate Nginx Cache Hit Ratio
# Usage: ./calculate-hit-ratio.sh [log_file]
#
# Analyzes Nginx access logs and reports cache hit/miss statistics

set -euo pipefail

LOG="${1:-/var/log/nginx/okome_access.log}"

if [ ! -f "$LOG" ]; then
  echo "Error: Log file not found: $LOG"
  exit 1
fi

echo "Analyzing cache hit ratio from: $LOG"
echo ""

# Count hits and misses
HIT=$(grep -c "cache=HIT" "$LOG" 2>/dev/null || echo "0")
MISS=$(grep -c "cache=MISS" "$LOG" 2>/dev/null || echo "0")
BYPASS=$(grep -c "cache=BYPASS" "$LOG" 2>/dev/null || echo "0")
EXPIRED=$(grep -c "cache=EXPIRED" "$LOG" 2>/dev/null || echo "0")
UPDATING=$(grep -c "cache=UPDATING" "$LOG" 2>/dev/null || echo "0")

TOTAL=$((HIT + MISS))
if [ "$TOTAL" -eq 0 ]; then
  TOTAL=1
fi

HIT_RATIO=$(awk "BEGIN {printf \"%.2f\", ($HIT / $TOTAL) * 100}")

echo "Cache Statistics:"
echo "  HIT:     $HIT"
echo "  MISS:    $MISS"
echo "  BYPASS:  $BYPASS"
echo "  EXPIRED: $EXPIRED"
echo "  UPDATING: $UPDATING"
echo ""
echo "Hit Ratio: ${HIT_RATIO}% (${HIT}/${TOTAL} requests)"
echo ""
