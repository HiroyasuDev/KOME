# Phase 5: Enterprise Hardening

**Goal**: Add VIP failover, monitoring, security, and chaos testing

**Nodes**: Both Frontend (192.168.86.20) and Backend (192.168.86.19)

---

## Overview

This phase adds enterprise-grade features:
- **VIP Failover**: High availability with keepalived (192.168.86.18)
- **Monitoring**: Prometheus node exporter
- **Security**: SSH hardening, fail2ban
- **Chaos Testing**: Safe failure injection framework

## Part A: VIP Failover with keepalived

### Overview

The VIP (192.168.86.18) is a virtual IP managed by keepalived that floats between active and backup frontend nodes. **No separate Pi is needed.**

### Architecture

```
[ RPi3 A ] ← owns VIP (active, priority 150)
[ RPi3 B ] ← watches + takes VIP if A fails (backup, priority 100)
```

### Installation

On both frontend nodes:

```bash
sudo apt install -y keepalived
```

### Configuration

**Active Node** (192.168.86.20):
- Copy `configs/keepalived/keepalived-master.conf` to `/etc/keepalived/keepalived.conf`
- Set priority to 150

**Backup Node** (cold spare):
- Copy `configs/keepalived/keepalived-backup.conf` to `/etc/keepalived/keepalived.conf`
- Set priority to 100

### Enable

```bash
sudo systemctl enable --now keepalived
```

### Verification

```bash
# Check which node owns VIP
ip addr show | grep 192.168.86.18

# Test failover (stop keepalived on active node)
sudo systemctl stop keepalived
# Backup should claim VIP in ~2 seconds
```

## Part B: Prometheus Node Exporter

### Installation

On both nodes:

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-armv7.tar.gz
tar xzf node_exporter-*.tar.gz
sudo cp node_exporter-*/node_exporter /usr/local/bin/
```

### Configuration

Copy `configs/systemd/node-exporter.service` to `/etc/systemd/system/`

**Frontend node**: Listen on 192.168.86.20:9100  
**Backend node**: Listen on 192.168.86.19:9100

### Enable

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node-exporter
```

### Verification

```bash
curl http://192.168.86.20:9100/metrics | head
```

## Part C: SSH Hardening

### Step 1: Generate SSH Key (on workstation)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/okome_cache -C "okome-cache"
```

### Step 2: Install Key on Each Pi

```bash
ssh-copy-id -i ~/.ssh/okome_cache.pub pi@192.168.86.20
ssh-copy-id -i ~/.ssh/okome_cache.pub pi@192.168.86.19
```

### Step 3: Harden SSH Daemon

Copy `configs/ssh/sshd_config` to `/etc/ssh/sshd_config` (backup original first).

Add group:

```bash
sudo groupadd sshusers
sudo usermod -aG sshusers pi
```

Restart:

```bash
sudo systemctl restart ssh
```

## Part D: Fail2ban

### Installation

```bash
sudo apt install -y fail2ban
```

### Configuration

Copy `configs/fail2ban/jail.local` to `/etc/fail2ban/jail.local`

Restart:

```bash
sudo systemctl restart fail2ban
```

### Verification

```bash
fail2ban-client status sshd
```

## Part E: Chaos Testing

### Overview

Safe chaos testing framework for validating failover and recovery.

### Safety

- Chaos runs **only** if `/etc/okome/CHAOS_ENABLE` exists
- Chaos logs to RAM (`/tmp`)
- Default duration: 15 seconds

### Enable Chaos

On nodes you want chaos-enabled:

```bash
sudo mkdir -p /etc/okome
echo "I understand chaos testing." | sudo tee /etc/okome/CHAOS_ENABLE >/dev/null
```

### Usage

From workstation:

```bash
# Simulate upstream outage for 20s
./cache_nodes_012426_2236/scripts/okome-chaos.sh upstream-drop 20

# Stop nginx for 15s
./cache_nodes_012426_2236/scripts/okome-chaos.sh nginx-stop 15

# Force VIP failover for 25s
./cache_nodes_012426_2236/scripts/okome-chaos.sh vip-failover 25
```

### Available Scenarios

- `nginx-stop`: Stop Nginx temporarily
- `redis-stop`: Stop Redis temporarily
- `vip-failover`: Stop keepalived to force failover
- `upstream-drop`: Block packets to orchestrator
- `reboot-frontend`: Reboot frontend node
- `reboot-backend`: Reboot backend node

## Part F: Grafana Dashboard (Optional)

### Configuration

Copy `dashboards/grafana/okome-cache-hitmiss.json` to your Grafana instance.

### Prometheus Scrape Config

Add to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: okome-cache
    static_configs:
      - targets:
          - 192.168.86.20:9100
          - 192.168.86.19:9100
```

## Verification

### Test VIP Failover

1. Check active node: `ip addr show | grep 192.168.86.18`
2. Stop keepalived on active: `sudo systemctl stop keepalived`
3. Wait 2 seconds
4. Check backup node: `ip addr show | grep 192.168.86.18`
5. Backup should now own VIP

### Test Monitoring

```bash
# Node exporter
curl http://192.168.86.20:9100/metrics | grep -E "cpu|memory|disk"

# Nginx status
curl http://192.168.86.20/nginx_status

# Redis stats
redis-cli -h 192.168.86.19 info stats
```

### Test SSH Hardening

```bash
# Should work with key
ssh -i ~/.ssh/okome_cache pi@192.168.86.20

# Should fail with password
ssh pi@192.168.86.20
# (password auth should be disabled)
```

### Test Chaos

```bash
# Enable chaos first
ssh pi@192.168.86.20 "sudo mkdir -p /etc/okome && echo 'test' | sudo tee /etc/okome/CHAOS_ENABLE"

# Run chaos test
./cache_nodes_012426_2236/scripts/okome-chaos.sh nginx-stop 10

# Verify recovery
curl -I http://192.168.86.20/
```

## Troubleshooting

### VIP Not Failing Over

1. Check keepalived status: `systemctl status keepalived`
2. Check logs: `journalctl -u keepalived`
3. Verify network connectivity between nodes
4. Check firewall rules

### Node Exporter Not Responding

1. Check service: `systemctl status node-exporter`
2. Check port: `netstat -tlnp | grep 9100`
3. Verify firewall allows port 9100

### SSH Hardening Issues

1. Test with key: `ssh -i ~/.ssh/okome_cache pi@...`
2. Check SSH config: `sudo sshd -T | grep -E "PasswordAuthentication|PubkeyAuthentication"`
3. Verify key is installed: `cat ~/.ssh/authorized_keys` on Pi

## Next Steps

After completing Phase 5:
1. Test VIP failover scenarios
2. Set up Prometheus/Grafana (optional)
3. Run chaos tests to validate resilience
4. Proceed to [Phase 6: SRE Runbook & Documentation](06_SRE_RUNBOOK.md)

---

**Last Updated**: 2026-01-24
