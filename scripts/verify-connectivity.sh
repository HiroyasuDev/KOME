#!/bin/bash
# KOME Cache Node Connectivity Verification
# Verifies SSH connectivity to CN00 before deployment
# Usage: ./scripts/verify-cache-node-connectivity.sh

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

echo -e "${GREEN}=== KOME Cache Node Connectivity Verification ===${NC}"
echo "Target: ${CACHE_USER}@${CACHE_IP}:${CACHE_PORT}"
echo ""

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
  echo -e "${RED}Error: sshpass not found${NC}"
  echo "Install with: brew install hudochenkov/sshpass/sshpass (macOS)"
  echo "Or: sudo apt-get install sshpass (Linux)"
  exit 1
fi

# Step 1: Ping test
echo -e "${GREEN}[1/4] Testing network connectivity (ping)...${NC}"
if ping -c 2 -W 2 "${CACHE_IP}" &>/dev/null; then
  echo -e "${GREEN}✓ Host is reachable${NC}"
else
  echo -e "${RED}✗ Host is not reachable (ping failed)${NC}"
  echo -e "${YELLOW}  Possible causes:${NC}"
  echo -e "${YELLOW}    - Cache node is offline${NC}"
  echo -e "${YELLOW}    - Network connectivity issue${NC}"
  echo -e "${YELLOW}    - Firewall blocking ICMP${NC}"
  echo ""
  read -p "Continue with SSH test anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Step 2: Port connectivity test
echo -e "${GREEN}[2/4] Testing SSH port connectivity...${NC}"
if timeout 3 bash -c "echo > /dev/tcp/${CACHE_IP}/${CACHE_PORT}" 2>/dev/null; then
  echo -e "${GREEN}✓ Port ${CACHE_PORT} is open${NC}"
else
  echo -e "${RED}✗ Port ${CACHE_PORT} is closed or filtered${NC}"
  echo -e "${YELLOW}  Possible causes:${NC}"
  echo -e "${YELLOW}    - SSH service not running on cache node${NC}"
  echo -e "${YELLOW}    - Firewall blocking port ${CACHE_PORT}${NC}"
  echo -e "${YELLOW}    - Wrong port number${NC}"
  echo ""
  echo -e "${YELLOW}Note: Standard SSH port 22 is used${NC}"
  echo ""
  read -p "Continue with SSH authentication test anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Step 3: SSH authentication test
echo -e "${GREEN}[3/4] Testing SSH authentication...${NC}"
if sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "${CACHE_USER}@${CACHE_IP}" \
  "echo 'SSH connection successful' && hostname && whoami" 2>&1; then
  echo -e "${GREEN}✓ SSH authentication successful${NC}"
else
  echo -e "${RED}✗ SSH authentication failed${NC}"
  echo -e "${YELLOW}  Possible causes:${NC}"
  echo -e "${YELLOW}    - Incorrect password${NC}"
  echo -e "${YELLOW}    - User '${CACHE_USER}' does not exist${NC}"
  echo -e "${YELLOW}    - SSH service configuration issue${NC}"
  exit 1
fi

# Step 4: System information
echo -e "${GREEN}[4/4] Gathering system information...${NC}"
sshpass -p "${CACHE_PASSWORD}" \
  ssh -p "${CACHE_PORT}" -o StrictHostKeyChecking=no \
  "${CACHE_USER}@${CACHE_IP}" \
  "echo '--- System Info ---' && \
   uname -a && \
   echo '' && \
   echo '--- OS Version ---' && \
   cat /etc/os-release 2>/dev/null | grep PRETTY_NAME || echo 'OS info not available' && \
   echo '' && \
   echo '--- Disk Space ---' && \
   df -h / | tail -1 && \
   echo '' && \
   echo '--- Memory ---' && \
   free -h | head -2" 2>&1

echo ""
echo -e "${GREEN}=== Connectivity Verification Complete ===${NC}"
echo ""
echo "Cache node is reachable and ready for deployment."
echo "Run: ./scripts/deploy.sh"
echo ""
