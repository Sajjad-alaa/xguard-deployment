#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl prometheus-node-exporter prometheus-process-exporter
systemctl enable --now prometheus-node-exporter prometheus-process-exporter
curl -fsSL https://get.docker.com | sh

install -d -m 0755 /opt/xguard-edge/certs
cat > /opt/xguard-edge/proxy.toml <<'CONFIG'
http_port = ${http_port}
https_port = ${https_port}
grpc_port = ${grpc_port}
cert_dir = "/etc/xguard/certs"
log_level = "${log_level}"
rate_limit_per_second = 0
rate_limit_burst = 0
CONFIG
cat > /opt/xguard-edge/docker-compose.yaml <<'COMPOSE'
services:
  edge:
    image: ${image}
    restart: unless-stopped
    volumes:
      - /opt/xguard-edge/certs:/etc/xguard/certs
      - /opt/xguard-edge/proxy.toml:/etc/xguard/proxy.toml:ro
    ports:
      - "${grpc_port}:${grpc_port}"
      - "${http_port}:${http_port}"
      - "${https_port}:${https_port}"
COMPOSE

docker compose -f /opt/xguard-edge/docker-compose.yaml pull
docker compose -f /opt/xguard-edge/docker-compose.yaml up -d
