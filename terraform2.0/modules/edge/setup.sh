#!/usr/bin/env bash
set -e

LOG_FILE="/var/log/xguard.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

(
log "Installing prerequisites..."
apt update
apt install -y ca-certificates curl

log "Adding the XGuard APT repository..."
# The repo serves two suites: trixie (glibc >= 2.39, e.g. Ubuntu 24.04 / Debian 13) and
# bookworm (older glibc, e.g. Ubuntu 22.04 / Debian 12). Pick the one matching this host to
# avoid the known GLIBC_2.39 incompatibility.
. /etc/os-release
case "$VERSION_CODENAME" in
    noble | trixie) apt_dist="trixie" ;;
    *) apt_dist="bookworm" ;;
esac
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://apt.xguard.local/xguard.asc -o /etc/apt/keyrings/xguard.asc
chmod a+r /etc/apt/keyrings/xguard.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/xguard.asc] https://apt.xguard.local/ $apt_dist release-2.0" >/etc/apt/sources.list.d/xguard.list
apt update

log "Installing xguard-proxy package..."
%{ if package_version != "" ~}
apt install -y xguard-proxy=${package_version}
%{ else ~}
apt install -y xguard-proxy
%{ endif ~}

# The edge runs as the 'xguard' user, so the cert dir must be writable by it.
log "Ensuring certificate directory exists..."
mkdir -p /etc/xguard/certs
chown -R xguard:xguard /etc/xguard/certs

log "Writing edge configuration to /etc/xguard/proxy.toml..."
tee /etc/xguard/proxy.toml <<EOF
# XGuard Edge (proxy) configuration (2.0)

# Port the API/enrollment HTTP server listens on
http_port = ${http_port}
# Port the HTTPS server listens on (used after Core provisions TLS)
https_port = ${https_port}
# Port the gRPC server listens on. Core connects here to adopt and manage the edge.
grpc_port = ${grpc_port}
# Directory where adoption-provisioned mTLS certificates are stored
cert_dir = "/etc/xguard/certs"

log_level = "${log_level}"
rate_limit_per_second = 0
rate_limit_burst = 0
# acme_staging = false
EOF

chown xguard:xguard /etc/xguard/proxy.toml

log "Enabling xguard-proxy service..."
systemctl enable xguard-proxy

log "Starting xguard-proxy service..."
systemctl start xguard-proxy

log "Setup completed."
) 2>&1 | tee -a "$LOG_FILE"
