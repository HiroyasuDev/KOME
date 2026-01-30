#!/bin/bash
# OKOME – raspi-config nonint helpers (optional). Phase 0.
# Run on Raspberry Pi OS. Uses raspi-config nonint if available.

set -euo pipefail

do_hostname() {
  local name="${1:-CN00}"
  if command -v raspi-config &>/dev/null; then
    sudo raspi-config nonint do_hostname "$name"
    echo "Hostname set to $name"
  else
    echo "raspi-config not found; use hostnamectl set-hostname $name"
  fi
}

do_gpu_mem() {
  local mb="${1:-16}"
  if command -v raspi-config &>/dev/null; then
    sudo raspi-config nonint do_memory_split "$mb"
    echo "GPU memory set to ${mb}MB"
  else
    echo "raspi-config not found; set GPU memory manually"
  fi
}

case "${1:-}" in
  hostname) do_hostname "${2:-CN00}" ;;
  gpu)      do_gpu_mem "${2:-16}" ;;
  *)
    echo "Usage: $0 hostname [CN00|CN01] | gpu [16|32]"
    exit 1
    ;;
esac
