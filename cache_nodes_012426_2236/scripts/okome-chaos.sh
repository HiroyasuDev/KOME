#!/bin/bash
# OKOME chaos testing (stub). Phase 5.
# Guard: CHAOS_ENABLE. Scenarios: nginx-stop, redis-stop, vip-failover.
set -euo pipefail
[ -f "${CHAOS_ENABLE:-/tmp/CHAOS_ENABLE}" ] || { echo "CHAOS_ENABLE not set"; exit 1; }
echo "okome-chaos stub"
