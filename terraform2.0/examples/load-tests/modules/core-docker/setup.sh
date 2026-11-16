#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl prometheus-node-exporter prometheus-process-exporter
systemctl enable --now prometheus-node-exporter prometheus-process-exporter
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

wait_for_port() {
  local host="$1"
  local port="$2"
  local attempts="$3"
  local i=0
  while [ "$i" -lt "$attempts" ]; do
    if timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
      return 0
    fi
    i=$((i + 1))
    sleep 5
  done
  return 1
}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

log "Waiting for PostgreSQL to become reachable..."
wait_for_port "${db_address}" "${db_port}" 60

log "Waiting for gateway and edge gRPC servers to become reachable..."
wait_for_port "${gateway_address}" "${gateway_grpc_port}" 60 || log "WARNING: gateway is not reachable; auto-adoption may fail"
wait_for_port "${edge_address}" "${edge_grpc_port}" 60 || log "WARNING: edge is not reachable; auto-adoption may fail"

install -d -m 0755 /opt/xguard-core
cat > /opt/xguard-core/docker-compose.yaml <<'COMPOSE'
services:
  core:
    image: ${image}
    restart: unless-stopped
    environment:
      XGUARD_GRPC_PORT: "${grpc_port}"
      XGUARD_HTTP_PORT: "${http_port}"
      XGUARD_HTTP_BIND_ADDRESS: "0.0.0.0"
      XGUARD_GRPC_BIND_ADDRESS: "0.0.0.0"
      XGUARD_COOKIE_INSECURE: "${cookie_insecure}"
      XGUARD_LOG_LEVEL: "${log_level}"
      XGUARD_ADOPT_GATEWAY: "${gateway_address}:${gateway_grpc_port}"
      XGUARD_ADOPT_EDGE: "${edge_address}:${edge_grpc_port}"
      XGUARD_DB_HOST: "${db_address}"
      XGUARD_DB_PORT: "${db_port}"
      XGUARD_DB_NAME: "${db_name}"
      XGUARD_DB_USER: "${db_username}"
      XGUARD_DB_PASSWORD: "${db_password}"
      XGUARD_DB_POOL_SIZE: 50
    ports:
      - "${http_port}:${http_port}"
      - "${grpc_port}:${grpc_port}"
COMPOSE
chmod 600 /opt/xguard-core/docker-compose.yaml

docker compose -f /opt/xguard-core/docker-compose.yaml pull
docker compose -f /opt/xguard-core/docker-compose.yaml up -d
