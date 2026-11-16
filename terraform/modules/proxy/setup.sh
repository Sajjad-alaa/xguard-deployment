#!/usr/bin/env bash
set -e

LOG_FILE="/var/log/xguard.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

(
log "Updating apt repositories..."
apt update

log "Installing curl..."
apt install -y curl

log "Downloading xguard-proxy package..."
curl -fsSL -o /tmp/xguard-proxy.deb https://github.com/Sajjad-alaa/xguard-proxy/releases/download/v${package_version}/xguard-proxy-${package_version}-${arch}-unknown-linux-gnu.deb

log "Installing xguard-proxy package..."
dpkg -i /tmp/xguard-proxy.deb

log "Writing proxy configuration to /etc/xguard/proxy.toml..."
tee /etc/xguard/proxy.toml <<EOF
# port the API server will listen on
http_port = ${http_port}
# port the gRPC server will listen on
grpc_port = ${grpc_port}

log_level = "${log_level}"
rate_limit_per_second = 0
rate_limit_burst = 0
url = "${proxy_url}"

EOF

log "Enabling xguard-proxy service..."
systemctl enable xguard-proxy

log "Starting xguard-proxy service..."
systemctl start xguard-proxy

log "Cleaning up after installing XGuard Proxy..."
rm -f /tmp/xguard-proxy.deb

log "Setup completed."
) 2>&1 | tee -a "$LOG_FILE"
