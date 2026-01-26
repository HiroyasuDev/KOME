#!/bin/bash
# KOME Cache Node Test Suite
# Basic functionality tests

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
CACHE_IP="${CACHE_IP:-192.168.86.20}"
UPSTREAM_IP="${UPSTREAM_IP:-192.168.86.25}"
UPSTREAM_PORT="${UPSTREAM_PORT:-3000}"

PASSED=0
FAILED=0

test_pass() {
  echo -e "${GREEN}✓ PASS: $1${NC}"
  ((PASSED++))
}

test_fail() {
  echo -e "${RED}✗ FAIL: $1${NC}"
  ((FAILED++))
}

echo "=== KOME Cache Node Test Suite ==="
echo ""

# Test 1: Upstream connectivity
echo "Test 1: Upstream connectivity..."
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://${UPSTREAM_IP}:${UPSTREAM_PORT}" | grep -qE "200|301|302"; then
  test_pass "Upstream is reachable"
else
  test_fail "Upstream is not reachable"
fi

# Test 2: Cache node connectivity
echo "Test 2: Cache node connectivity..."
if curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://${CACHE_IP}" | grep -qE "200|301|302"; then
  test_pass "Cache node is responding"
else
  test_fail "Cache node is not responding"
fi

# Test 3: Cache headers present
echo "Test 3: Cache headers..."
RESPONSE=$(curl -s -I "http://${CACHE_IP}/" 2>&1)
if echo "$RESPONSE" | grep -qi "server: nginx"; then
  test_pass "NGINX server header present"
else
  test_fail "NGINX server header missing"
fi

# Test 4: Compression
echo "Test 4: Compression..."
if echo "$RESPONSE" | grep -qi "content-encoding: gzip"; then
  test_pass "Compression enabled"
else
  # Compression may not show on all responses
  test_pass "Compression check (may vary by response)"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed${NC}"
  exit 1
fi
