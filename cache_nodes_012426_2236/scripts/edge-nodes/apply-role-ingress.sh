#!/usr/bin/env bash
# Apply Ingress + Router role to NODE-01/02 (192.168.86.41, .42): NGINX with sticky routing to OKOME .25.
# Run ON 192.168.86.41 or .42. See docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md.

set -euo pipefail

OKOME_UPSTREAM="${OKOME_UPSTREAM:-192.168.86.25:8000}"

echo "Applying Ingress/Router role (NGINX, sticky to ${OKOME_UPSTREAM})..."

if ! command -v nginx &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y nginx
fi

# Sticky upstream: hash $remote_addr or $cookie_* for session affinity
sudo tee /etc/nginx/sites-available/okome-ingress <<EOF
upstream okome_gateway {
    hash \$remote_addr consistent;
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
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_connect_timeout 5s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/okome-ingress /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl reload nginx
echo "OK: Ingress (NGINX) with sticky routing to ${OKOME_UPSTREAM}"
echo "Verify: curl -I http://127.0.0.1/"