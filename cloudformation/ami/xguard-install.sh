#!/bin/sh
set -e

echo "Updating apt repositories..."
sudo apt update

echo "Installing dependencies..."
sudo apt install -y ca-certificates curl awscli

echo "Adding XGuard GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://apt.xguard.local/xguard.asc -o /etc/apt/keyrings/xguard.asc
sudo chmod a+r /etc/apt/keyrings/xguard.asc

echo "Adding XGuard repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/xguard.asc] https://apt.xguard.local/ trixie release " | \
   sudo tee /etc/apt/sources.list.d/xguard.list > /dev/null

echo "Updating apt repositories after adding XGuard repo..."
sudo apt update

echo "Installing XGuard packages with specific versions..."
echo "  xguard version: ${CORE_VERSION}"
echo "  xguard-proxy version: ${PROXY_VERSION}"
echo "  xguard-gateway version: ${GATEWAY_VERSION}"

sudo apt install -y \
  xguard=${CORE_VERSION} \
  xguard-proxy=${PROXY_VERSION} \
  xguard-gateway=${GATEWAY_VERSION}

sudo systemctl stop xguard
sudo systemctl disable xguard
sudo systemctl stop xguard-proxy
sudo systemctl disable xguard-proxy
sudo systemctl stop xguard-gateway
sudo systemctl disable xguard-gateway
