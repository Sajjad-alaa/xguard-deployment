#!/usr/bin/env bash
set -e

LOG_FILE="/var/log/xguard.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

generate_secret_inner() {
	local length="$1"
	openssl rand -base64 $${length} | tr -d "=+/" | tr -d '\n' | cut -c1-$${length-1} 
}

(
log "Updating apt repositories..."
apt update

log "Installing curl..."
apt install -y curl

log "Downloading xguard-core package..."
curl -fsSL -o /tmp/xguard-core.deb https://github.com/Sajjad-alaa/xguard-core/releases/download/v${package_version}/xguard-${package_version}-${arch}-unknown-linux-gnu.deb

log "Installing xguard-core package..."
dpkg -i /tmp/xguard-core.deb

log "Writing Core configuration to /etc/xguard/core.conf..."
tee /etc/xguard/core.conf <<EOF
### Core configuration ###
XGUARD_AUTH_SECRET=$(generate_secret_inner 64)
XGUARD_GATEWAY_SECRET=${gateway_secret}
XGUARD_YUBIBRIDGE_SECRET=$(generate_secret_inner 64)
XGUARD_SECRET_KEY=$(generate_secret_inner 64)
XGUARD_URL=${core_url}
# How long auth session lives in seconds
XGUARD_AUTH_SESSION_LIFETIME=604800
# Optional. Generated based on XGUARD_URL if not provided.
# XGUARD_WEBAUTHN_RP_ID=localhost
XGUARD_ADMIN_GROUPNAME=admin
XGUARD_DEFAULT_ADMIN_PASSWORD=${default_admin_password}
XGUARD_GRPC_PORT=${grpc_port}
XGUARD_HTTP_PORT=${http_port}
XGUARD_COOKIE_INSECURE=${cookie_insecure}
XGUARD_LOG_LEVEL=${log_level}

### Proxy configuration ###
# Optional. URL of proxy gRPC server
XGUARD_PROXY_URL=http://${proxy_address}:${proxy_grpc_port}
XGUARD_ENROLLMENT_URL=${proxy_url}

### DB configuration ###
XGUARD_DB_HOST="${db_address}"
XGUARD_DB_PORT=${db_port}
XGUARD_DB_NAME="${db_name}"
XGUARD_DB_USER="${db_username}"
XGUARD_DB_PASSWORD="${db_password}"
EOF

log "Enabling XGuard service..."
systemctl enable xguard

log "Starting XGuard service..."
systemctl start xguard

%{ for network in vpn_networks ~}
log "Creating VPN location ${network.name} with address ${network.address} and endpoint ${network.endpoint} and port ${network.port}..."
export $(grep -v '^#' /etc/xguard/core.conf | xargs) && /usr/bin/xguard --secret-key ${gateway_secret} init-vpn-location --name ${network.name} --address ${network.address} --endpoint ${network.endpoint} --port ${network.port} --id ${network.id} --allowed-ips ${network.address} >> "$LOG_FILE" 2>&1
log "Created VPN location ${network.name} with address ${network.address} and endpoint ${network.endpoint} and port ${network.port}"
%{ endfor ~}

log "Cleaning up after installing XGuard Core..."
rm -f /tmp/xguard-core.deb

log "Setup completed."
) 2>&1 | tee -a "$LOG_FILE"
