#!/usr/bin/env bash
# Apply base config to EDGE nodes 41–50 (and optionally .30, .25): sysctl, limits, CPU governor.
# Run ON each node (or via SSH from a central host). See docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
CONFIGS="${CONFIGS:-${SCRIPT_DIR}/../../configs/edge-nodes}"

echo "Applying base config (sysctl, limits, governor)..."

# Sysctl
if [[ -f "${CONFIGS}/sysctl-99-okome-distributed.conf" ]]; then
  sudo cp "${CONFIGS}/sysctl-99-okome-distributed.conf" /etc/sysctl.d/99-okome-distributed.conf
  sudo sysctl -p /etc/sysctl.d/99-okome-distributed.conf
  echo "OK: sysctl applied"
fi

# Limits
if [[ -f "${CONFIGS}/limits-99-okome.conf" ]]; then
  sudo cp "${CONFIGS}/limits-99-okome.conf" /etc/security/limits.d/99-okome.conf
  echo "OK: limits applied (log out/in or reboot for full effect)"
fi

# CPU governor: performance
if command -v cpupower &>/dev/null; then
  sudo cpupower frequency-set -g performance 2>/dev/null && echo "OK: governor performance" || echo "WARN: cpupower failed (install linux-tools-common)"
elif [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee "$g" >/dev/null 2>/dev/null || true
  done
  echo "OK: governor performance (sysfs)"
fi

echo "Base config done."
