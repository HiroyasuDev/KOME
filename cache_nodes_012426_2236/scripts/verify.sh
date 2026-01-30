#!/usr/bin/env bash
# Verify OKOME Two-Node Cache Setup
# Usage: ./verify.sh

set -euo pipefail

FRONTEND="192.168.86.20"
BACKEND="192.168.86.19"
UPSTREAM="192.168.86.25:8000"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================="
echo "OKOME Cache Nodes Verification"
echo "=============================="
echo ""

# Frontend Node Check
echo -e "${YELLOW}[FRONTEND] Cache node: ${FRONTEND}${NC}"
if curl -fsSI "http://${FRONTEND}/" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Frontend node is responding${NC}"
  curl -sI "http://${FRONTEND}/" | grep -i "X-Cache\|X-OKOME\|HTTP" || true
else
  echo -e "${RED}✗ Frontend node is not responding${NC}"
fi
echo ""

# Backend Node Check
echo -e "${YELLOW}[BACKEND] Cache node: ${BACKEND}${NC}"
if redis-cli -h "${BACKEND}" ping > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Backend Redis is responding${NC}"
  redis-cli -h "${BACKEND}" info memory | grep -E "used_memory_human|maxmemory_human" || true
else
  echo -e "${RED}✗ Backend Redis is not responding${NC}"
fi
echo ""

# Upstream Check
echo -e "${YELLOW}[UPSTREAM] Orchestrator: ${UPSTREAM}${NC}"
if curl -fsSI "http://${UPSTREAM}/health" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Upstream orchestrator is responding${NC}"
else
  echo -e "${RED}✗ Upstream orchestrator is not responding${NC}"
fi
echo ""

echo "=============================="
echo "Verification complete"
echo "=============================="
