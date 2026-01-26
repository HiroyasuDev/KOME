# Phase 0: Foundation & SD Hardening

Goal: SD wear reduction and golden-image readiness for both cache nodes (frontend 192.168.86.20, backend 192.168.86.19).

## Raspi-Config

- Hostname: `CN00` (frontend) / `CN01` (backend)
- GPU memory: 16–32 MB (headless)
- Interfaces: eth0 static; WiFi optional

## Static IP

- Frontend: 192.168.86.20/24, gateway 192.168.86.1  
- Backend: 192.168.86.19/24, gateway 192.168.86.1  

Use NetworkManager (`nmcli`) or `/etc/dhcpcd.conf` per [01_BASIC_SETUP.md](01_BASIC_SETUP.md).

## Journald (RAM-only)

`configs/journald-okome.conf` → `/etc/systemd/journald.conf.d/okome.conf`:

- `Storage=volatile`
- `RuntimeMaxUse=50M`

Restart: `systemctl restart systemd-journald`.

## Sysctl

`configs/sysctl-okome.conf` → `/etc/sysctl.d/okome.conf`:

- `vm.dirty_ratio`, `vm.dirty_background_ratio` (fewer syncs)
- `net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`

Apply: `sysctl -p /etc/sysctl.d/okome.conf`.

## Fstab (optional)

`configs/fstab-hardened.conf`: `noatime`, `commit=60` on root; tmpfs for `/var/cache/nginx` (frontend) if desired. Merge into `/etc/fstab` carefully.

## Service Pruning

- `systemctl disable bluetooth avahi-daemon`  
- Stopped by `install_frontend_cache.sh` / `install_backend_cache.sh` / `reconfigure_backend_production.sh`.

## Golden Image

`scripts/create-golden-image.sh`: documents cloning procedure (SD image, first-boot hostname/IP per node). Run after hardening one node to duplicate.

## Storage

See [docs/STORAGE_SPEC.md](docs/STORAGE_SPEC.md): 32GB A1 microSD for both nodes.
