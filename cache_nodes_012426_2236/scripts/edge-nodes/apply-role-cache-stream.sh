#!/usr/bin/env bash
# Apply Edge Cache/Stream role to NODE-03–06 (192.168.86.43–.46): Redis + low-latency proxy to OKOME .25.
# Run ON 192.168.86.43, .44, .45, or .46. See docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md.

set -euo pipefail

OKOME_UPSTREAM="${OKOME_UPSTREAM:-192.168.86.25:8000}"

echo "Applying Cache/Stream role (Redis + proxy to ${OKOME_UPSTREAM})..."

# Redis
if ! command -v redis-server &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y redis-server
fi
sudo systemctl enable redis-server
sudo systemctl start redis-server || true

# Optional: NGINX as streaming proxy to OKOME (no cache for API; cache for static)
if ! command -v nginx &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y nginx
fi

sudo tee /etc/nginx/sites-available/okome-cache-stream <<EOF
upstream okome_gateway {
    server ${OKOME_UPSTREAM} max_fails=3 fail_timeout=10s;
    keepalive 64;
}

server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://okome_gateway;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_request_buffering off;
        chunked_transfer_encoding on;
        proxy_connect_timeout 5s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/okome-cache-stream /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl reload nginx
echo "OK: Cache/Stream (Redis + NGINX proxy to ${OKOME_UPSTREAM})"
redis-cli ping
echo "Verify: curl -I http://127.0.0.1/"