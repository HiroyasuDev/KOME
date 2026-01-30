#!/usr/bin/env bash
# Create Golden Image for OKOME Cache Nodes
# Usage: Run on a prepared Raspberry Pi before cloning
#
# This script prepares a Pi for imaging by:
# 1. Cleaning package cache
# 2. Clearing identity-specific state
# 3. Ensuring clean shutdown

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== OKOME Golden Image Preparation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Step 1: Update and clean packages
echo -e "${GREEN}[1/4] Cleaning package cache...${NC}"
apt-get update
apt-get upgrade -y
apt-get autoremove -y
apt-get clean

# Step 2: Clear identity-specific state
echo -e "${GREEN}[2/4] Clearing machine identity...${NC}"
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Step 3: Clear logs (they're in tmpfs anyway, but be thorough)
echo -e "${GREEN}[3/4] Clearing logs...${NC}"
journalctl --vacuum-time=1s || true
rm -rf /var/log/*.log /var/log/*.log.* || true

# Step 4: Final checks
echo -e "${GREEN}[4/4] Verification...${NC}"
echo "Machine ID: $(cat /etc/machine-id)"
echo "Hostname: $(hostname)"
echo ""

echo -e "${YELLOW}Golden image preparation complete.${NC}"
echo ""
echo "Next steps:"
echo "1. Power off: sudo poweroff"
echo "2. Remove SD card"
echo "3. Clone using: sudo dd if=/dev/sdX of=okome-golden.img bs=4M status=progress conv=fsync"
echo "4. Compress: xz -T0 okome-golden.img"
echo ""
