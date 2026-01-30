# Phase 0: Foundation & SD Hardening

**Goal**: Create golden image with SD wear reduction for both cache nodes

**Target**: Raspberry Pi 3+ v1.5  
**OS**: Raspberry Pi OS Lite (32-bit)  
**Applies to**: Frontend cache (192.168.86.20) & Backend cache (192.168.86.19)

---

## Overview

This phase creates a hardened, SD-friendly base image that can be cloned to both cache nodes. The configuration minimizes SD card writes to maximize lifespan and ensures both nodes are stateless and disposable.

## Prerequisites

- Raspberry Pi 3+ v1.5 (or newer)
- 32GB A1-rated microSD card (recommended)
- Raspberry Pi OS Lite (32-bit) image
- SSH access enabled

## Step 1: OS Installation

1. Download Raspberry Pi OS Lite (32-bit) from official site
2. Flash to microSD card using Raspberry Pi Imager or `dd`
3. Enable SSH by creating `ssh` file in boot partition
4. Boot Pi and connect via SSH

## Step 2: raspi-config Settings

Run `sudo raspi-config` and configure:

### System Options
- **S1 Hostname**: 
  - Frontend: `okome-edge-01`
  - Backend: `okome-cache-01`
- **S3 Password**: Change default password
- **S4 Boot / Auto Login**: 
  - `B1 Console`
  - `B2 Console Autologin` → **Disable** (no autologin)

### Display Options
- Skip entirely (no desktop)

### Interface Options
- **I2 SSH** → **Enable**
- Everything else → **Disable**

### Performance Options
- **P2 GPU Memory**: Set to **16 MB**

### Localisation
- Set timezone, locale, keyboard as needed

### Advanced Options
- **A1 Expand Filesystem** → **Enable**
- **A3 Memory Split**: Leave default (GPU already set to 16MB)
- **A4 Network Interface Names**: **Enable** (predictable names)

Reboot: `sudo reboot`

## Step 3: Disable Swap

```bash
sudo dphys-swapfile swapoff
sudo systemctl disable dphys-swapfile
sudo systemctl stop dphys-swapfile
```

Verify: `free -h` (should show 0 swap)

## Step 4: Harden /etc/fstab

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

**Replace with** (or carefully merge):

```fstab
proc            /proc           proc    defaults                          0 0
PARTUUID=XXXXXX /               ext4    defaults,noatime,commit=60         0 1

tmpfs           /tmp            tmpfs   defaults,noatime,nosuid,size=100m  0 0
tmpfs           /var/tmp        tmpfs   defaults,noatime,nosuid,size=50m   0 0
tmpfs           /var/log        tmpfs   defaults,noatime,nosuid,size=50m   0 0
```

> **Important**: Replace `PARTUUID=XXXXXX` with actual value from `blkid` or `lsblk -o PARTUUID`

**Why this matters**:
- `noatime`: Eliminates access time writes
- `commit=60`: Reduces filesystem sync frequency
- `tmpfs` for logs: Logs live in RAM, zero SD writes

## Step 5: Journald → RAM Only

Edit `/etc/systemd/journald.conf`:

```bash
sudo nano /etc/systemd/journald.conf
```

Set:

```ini
Storage=volatile
RuntimeMaxUse=20M
SystemMaxUse=0
```

Restart:

```bash
sudo systemctl restart systemd-journald
```

## Step 6: Kernel & Filesystem Tweaks

Create `/etc/sysctl.d/99-okome.conf`:

```bash
sudo nano /etc/sysctl.d/99-okome.conf
```

Paste:

```ini
# Reduce cache pressure
vm.swappiness=1
vm.vfs_cache_pressure=50

# Network safety
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5

# File handles
fs.inotify.max_user_watches=524288
```

Apply:

```bash
sudo sysctl --system
```

## Step 7: Service Pruning

Disable unnecessary services:

```bash
sudo systemctl disable triggerhappy
sudo systemctl disable bluetooth
sudo systemctl disable avahi-daemon
sudo systemctl disable hciuart
```

Check active services:

```bash
systemctl --type=service --state=running
```

## Step 8: Golden Image Preparation

Before imaging:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt clean
```

Clear identity-specific state:

```bash
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

Power off cleanly:

```bash
sudo poweroff
```

## Step 9: Clone the SD Card

On your Mac/Linux machine:

```bash
# Identify SD device
lsblk   # e.g., /dev/sdX

# Clone
sudo dd if=/dev/sdX of=okome-golden.img bs=4M status=progress conv=fsync

# Compress
xz -T0 okome-golden.img
```

Flash to second card:

```bash
# Identify second SD device
lsblk   # e.g., /dev/sdY

# Flash
xzcat okome-golden.img.xz | sudo dd of=/dev/sdY bs=4M status=progress conv=fsync
```

## Step 10: First Boot After Clone

After cloning, on **each Pi**:

```bash
sudo systemd-machine-id-setup
sudo hostnamectl set-hostname okome-edge-01   # or okome-cache-01
sudo reboot
```

Then:
- Assign static IP (192.168.86.20 or 192.168.86.19)
- Install role-specific service (Nginx or Redis)
- Drop in OKOME configs

## Verification

After hardening, verify:

```bash
# Check swap is disabled
free -h

# Check fstab mounts
mount | grep -E "tmpfs|noatime"

# Check journald
journalctl --disk-usage

# Check services
systemctl list-unit-files --state=enabled | grep -E "bluetooth|avahi|triggerhappy"
```

## Failure Model

- SD dies → reflash image
- Power loss → no corruption (tmpfs logs)
- Cache loss → safe regeneration
- No writes → long SD lifespan
- Node disposable → infra resilient

## Next Steps

After completing Phase 0:
1. Clone golden image to both Pis
2. Configure static IPs
3. Proceed to [Phase 1: Basic Setup](01_BASIC_SETUP.md)

---

**Last Updated**: 2026-01-24
