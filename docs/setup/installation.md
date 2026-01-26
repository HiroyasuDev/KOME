# KOME Installation Guide

## Prerequisites

### Hardware Requirements

- **Raspberry Pi 3 or newer** (Pi 4 recommended)
- **16GB+ microSD card** (32GB recommended, Class 10 / A1 minimum)
- **Ethernet connection** (recommended for stability)
- **Power supply** (official Raspberry Pi power supply recommended)

### Software Requirements

- **Raspberry Pi OS Lite** (64-bit if supported)
- **Static IP configuration**: 192.168.86.20
- **SSH access** enabled

## Installation Steps

### Step 1: Prepare Raspberry Pi

1. **Flash Raspberry Pi OS Lite** to microSD card
2. **Enable SSH**: Create empty `ssh` file in boot partition
3. **Configure WiFi** (if using): Create `wpa_supplicant.conf` in boot partition
4. **Boot Raspberry Pi** and connect via SSH

### Step 2: Configure Static IP

Edit `/etc/dhcpcd.conf`:

```bash
sudo nano /etc/dhcpcd.conf
```

Add:

```
interface eth0
static ip_address=192.168.86.20/24
static routers=192.168.86.1
static domain_name_servers=192.168.86.1
```

Reboot:

```bash
sudo reboot
```

### Step 3: Clone KOME Repository

```bash
cd ~
git clone https://github.com/HiroyasuDev/KOME.git
cd KOME
```

### Step 4: Run Bootstrap Script

```bash
sudo ./scripts/bootstrap.sh
```

This will:
- Update system packages
- Install NGINX
- Configure log rotation
- Set up tmpfs cache
- Configure NGINX cache
- Start NGINX service

### Step 5: Verify Installation

```bash
# Test NGINX configuration
sudo nginx -t

# Test cache node
curl -I http://192.168.86.20

# Check NGINX status
sudo systemctl status nginx
```

## Post-Installation

### Verify Upstream Connectivity

```bash
# Test upstream (OKOME core)
curl -I http://192.168.86.25:3000
```

### Test Cache Functionality

```bash
# From your local machine
./scripts/test.sh
```

## Troubleshooting

### NGINX Won't Start

1. Check configuration:
   ```bash
   sudo nginx -t
   ```

2. Check logs:
   ```bash
   sudo tail -50 /var/log/nginx/error.log
   ```

3. Check if port 80 is in use:
   ```bash
   sudo netstat -tulpn | grep :80
   ```

### Upstream Connection Failed

1. Verify OKOME core is running:
   ```bash
   curl -I http://192.168.86.25:3000
   ```

2. Check network connectivity:
   ```bash
   ping 192.168.86.25
   ```

3. Verify firewall rules (if applicable)

### Cache Not Working

1. Check cache directory permissions:
   ```bash
   sudo ls -ld /var/cache/nginx/static
   ```

2. Verify cache configuration:
   ```bash
   sudo cat /etc/nginx/conf.d/kome-cache.conf | grep proxy_cache
   ```

3. Check access logs:
   ```bash
   sudo tail -f /var/log/nginx/access.log | grep X-Cache
   ```

## Next Steps

- Configure clients to use cache node: See `docs/guides/client-config.md`
- Monitor cache performance: `./scripts/stats.sh`
- Review operations runbook: `docs/operations/runbook.md`
