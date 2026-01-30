#!/usr/bin/env bash
# Apply Control/Observability role to NODE-09/10 (192.168.86.49, .50): Prometheus, Grafana, Loki.
# Run ON 192.168.86.49 or .50. See docs/DISTRIBUTED_10_NODE_ARCHITECTURE.md.

set -euo pipefail

echo "Applying Observability role (Prometheus, Grafana, Loki)..."

# Prometheus
if ! command -v prometheus &>/dev/null; then
  PROM_VER="${PROM_VER:-2.45.0}"
  PROM_DIR="/opt/prometheus"
  sudo mkdir -p "${PROM_DIR}"
  sudo useradd -r -s /bin/false prometheus 2>/dev/null || true
  curl -sSL "https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz" | sudo tar -xz -C /tmp
  sudo cp "/tmp/prometheus-${PROM_VER}.linux-amd64/prometheus" "${PROM_DIR}/"
  sudo cp "/tmp/prometheus-${PROM_VER}.linux-amd64/promtool" "${PROM_DIR}/"
  sudo mkdir -p /etc/prometheus
  echo "prometheus installed to ${PROM_DIR}; add systemd unit and config under /etc/prometheus"
fi

# Grafana (apt)
if ! command -v grafana-server &>/dev/null; then
  sudo apt-get install -y apt-transport-https software-properties-common
  wget -q -O - https://apt.grafana.com/gpg.key | sudo apt-key add -
  echo "deb https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  sudo apt-get update && sudo apt-get install -y grafana
  sudo systemctl enable grafana-server
  sudo systemctl start grafana-server || true
  echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/admin)"
fi

# Loki (optional: install from release or Docker)
echo "Loki: install from https://grafana.com/docs/loki/latest/installation/ if needed"

echo "OK: Observability (Prometheus, Grafana; Loki optional). Configure scrape targets for .25, .30, .41–.50."