#!/bin/bash
# OKOME – optional fstab tmpfs for /var/cache/nginx (frontend). Phase 0.
# Appends tmpfs line only if missing; backs up /etc/fstab first.
# Do NOT overwrite /etc/fstab. Merge root noatime/commit=60 manually.

set -euo pipefail

FSTAB="/etc/fstab"
MARK="# OKOME tmpfs nginx cache"

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo."
  exit 1
fi

if grep -q "$MARK" "$FSTAB" 2>/dev/null; then
  echo "OKOME tmpfs line already present."
  exit 0
fi

cp -a "$FSTAB" "${FSTAB}.bak.$(date +%Y%m%d%H%M%S)"
echo "" >> "$FSTAB"
echo "$MARK" >> "$FSTAB"
echo "tmpfs /var/cache/nginx tmpfs size=512m,noatime 0 0" >> "$FSTAB"
echo "Appended tmpfs line. Create /var/cache/nginx if missing, then: mount -a"
echo "Backup: ${FSTAB}.bak.*"
