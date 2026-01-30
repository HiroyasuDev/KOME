#!/usr/bin/env bash
# OKOME Predictive Pre-warm Script
# Analyzes access logs and warms cache for hottest URLs
# Location: /usr/local/bin/okome-prewarm.sh
# Runs via systemd timer every 2 minutes

set -euo pipefail

# Warm via VIP if present, else warm this node directly
TARGET="${OKOME_WARM_TARGET:-http://192.168.86.18}"

# How many URLs to warm
TOP_N="${OKOME_WARM_TOP_N:-40}"

# Nginx log file
LOG="${OKOME_NGINX_LOG:-/var/log/nginx/okome_access.log}"

# Filter to endpoints that are safe to warm
# (Add/remove patterns as you discover your real hot paths)
SAFE_REGEX='^/(|assets/|static/|ui-schema/|version|health)'

# Extract request paths, count frequency, take top N
URLS=$(awk '{print $7}' "$LOG" 2>/dev/null \
  | egrep -E "$SAFE_REGEX" \
  | sed 's/[?].*$//' \
  | sort | uniq -c | sort -nr \
  | head -n "$TOP_N" \
  | awk '{print $2}') || true

if [[ -z "${URLS:-}" ]]; then
  exit 0
fi

# Warm sequentially (safe for Pi + upstream)
while read -r path; do
  [[ -z "$path" ]] && continue
  # HEAD is enough to populate cache for many assets; fallback to GET if needed
  curl -fsS -I --max-time 2 "${TARGET}${path}" >/dev/null 2>&1 || true
done <<< "$URLS"
