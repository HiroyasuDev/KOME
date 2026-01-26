#!/bin/bash
# KOME Cache Node Deployment Script
# Deploys cache node configuration to CN00 (192.168.86.20)
# Usage: ./scripts/deploy-cache-node.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CACHE_IP="192.168.86.20"
CACHE_USER="ncadmin"
CACHE_PORT="22"
CACHE_PASSWORD="usshopper"
CORE_IP="192.168.86.25"
CORE_PORT="3000"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}=== KOME Cache Node Deployment ===${NC}"
echo "Target: ${CACHE_USER}@${CACHE_IP}:${CACHE_PORT}"
echo ""

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
  echo -e "${YELLOW}Installing sshpass...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install hudochenkov/sshpass/sshpass || {
      echo -e "${RED}Error: Please install sshpass manually${NC}"
      exit 1
    }
  else
    sudo apt-get install -y sshpass || {
      echo -e "${RED}Error: Please install sshpass manually${NC}"
      exit 1
    }
  fi
fi

# Test SSH connectivity
echo -e "${GREEN}[1/5] Testing SSH connectivity...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  "${CACHE_USER}@${CACHE_IP}" "echo 'SSH connection successful'" 2>&1; then
  echo -e "${GREEN}SSH connection verified${NC}"
else
  echo -e "${RED}Error: Cannot connect to cache node${NC}"
  exit 1
fi

# Upload bootstrap script
echo -e "${GREEN}[2/5] Uploading bootstrap script...${NC}"
sshpass -p "${CACHE_PASSWORD}" \
  scp -P "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${SCRIPT_DIR}/bootstrap.sh" \
  "${CACHE_USER}@${CACHE_IP}:/tmp/bootstrap.sh"

# Make script executable
sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "chmod +x /tmp/bootstrap.sh"

# Run bootstrap script with keepalive to prevent timeout
echo -e "${GREEN}[3/5] Running bootstrap script on cache node...${NC}"
sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=10 \
  -o TCPKeepAlive=yes \
  "${CACHE_USER}@${CACHE_IP}" \
  "sudo /tmp/bootstrap.sh" || {
  echo -e "${RED}Error: Bootstrap script failed${NC}"
  exit 1
}

# Verify upstream connectivity
echo -e "${GREEN}[4/5] Verifying upstream connectivity...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://${CORE_IP}:${CORE_PORT}" | grep -q "200\|301\|302"; then
  echo -e "${GREEN}Upstream (${CORE_IP}:${CORE_PORT}) is reachable${NC}"
else
  echo -e "${YELLOW}Warning: Upstream may not be reachable from cache node${NC}"
  echo -e "${YELLOW}Verify OptiPlex is running and accessible${NC}"
fi

# Test cache node
echo -e "${GREEN}[5/5] Testing cache node...${NC}"
sleep 2  # Give NGINX a moment to start
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://${CACHE_IP}" | grep -q "200\|301\|302"; then
  echo -e "${GREEN}Cache node is responding${NC}"
else
  echo -e "${YELLOW}Warning: Cache node may not be fully ready${NC}"
  echo -e "${YELLOW}Check manually: curl -I http://${CACHE_IP}${NC}"
fi

# Final verification
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Verification commands:"
echo "  # Test upstream"
echo "  curl -I http://${CORE_IP}:${CORE_PORT}"
echo ""
echo "  # Test cache node"
echo "  curl -I http://${CACHE_IP}/assets/app.js"
echo ""
echo "  # Check cache status"
echo "  sshpass -p '${CACHE_PASSWORD}' ssh -p ${CACHE_PORT} ${CACHE_USER}@${CACHE_IP} 'sudo tail -f /var/log/nginx/access.log'"
echo ""
echo "Cache node ready at: http://${CACHE_IP}"
echo ""
