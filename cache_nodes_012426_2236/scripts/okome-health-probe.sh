#!/usr/bin/env bash
# OKOME Upstream Health Probe — path through OKOME (192.168.86.25)
# Checks OKOME health and writes state file for Nginx
# Location: /usr/local/bin/okome-health-probe.sh
# Runs via systemd timer every 5 seconds

set -euo pipefail

UPSTREAM="http://192.168.86.25:8000/health"
OUT="/etc/nginx/okome/health_state.conf"
CURL_TIMEOUT=3

mkdir -p "$(dirname "$OUT")"

# Check OKOME upstream health (retry once on failure)
if curl -fsS --max-time "$CURL_TIMEOUT" --retry 1 "$UPSTREAM" >/dev/null 2>&1; then
  echo 'set $okome_upstream_ok 1;' | sudo tee "$OUT" >/dev/null
else
  echo 'set $okome_upstream_ok 0;' | sudo tee "$OUT" >/dev/null
fi

if sudo nginx -t >/dev/null 2>&1; then
  sudo systemctl reload nginx >/dev/null 2>&1 || true
fi
