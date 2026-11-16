#!/bin/bash
# Generates /opt/stacks/xguard/.env with random secrets on first boot.
# If .env already exists (e.g. provided via cloud-init), this script does nothing.
set -euo pipefail

STACK_DIR="${XGUARD_STACK_DIR:-/opt/stacks/xguard}"
INIT_DIR="${XGUARD_INIT_DIR:-$STACK_DIR/init}"
ENV_FILE="$STACK_DIR/.env"
PROFILES_FILE="$STACK_DIR/active-profiles"
DEPLOYMENT_MODE_FILE="$INIT_DIR/.deployment-mode"

if [ -f "$ENV_FILE" ]; then
  echo "XGuard: .env already exists, skipping generation."
  exit 0
fi

echo "XGuard: generating .env with random secrets..."

# shellcheck source=lib.sh
source "$INIT_DIR/lib.sh"

DB_PASSWORD=$(openssl rand -hex 16)

if [ -f "$INIT_DIR/.image-tags" ]; then
  source "$INIT_DIR/.image-tags"
fi

: "${XGUARD_CORE_TAG:?XGUARD_CORE_TAG is required}"
: "${XGUARD_PROXY_TAG:?XGUARD_PROXY_TAG is required}"
: "${XGUARD_GATEWAY_TAG:?XGUARD_GATEWAY_TAG is required}"

# Only default the adopt targets when core/edge/gateway are genuinely
# co-located on this host; segmented deployments must fill these in manually
# since edge/gateway live on other VMs entirely.
mapfile -t _profiles < <(resolve_profiles "$STACK_DIR")
PERSISTED_MODE="$(deployment_mode "$INIT_DIR")" \
  || { echo "XGuard: invalid deployment mode in $DEPLOYMENT_MODE_FILE" >&2; exit 1; }
if [ -n "${XGUARD_DEPLOYMENT_MODE:-}" ]; then
  MODE="$XGUARD_DEPLOYMENT_MODE"
elif [ "$PERSISTED_MODE" = segmented ]; then
  MODE=segmented
elif [ -f "$PROFILES_FILE" ]; then
  MODE=auto
else
  MODE="$PERSISTED_MODE"
fi
case "$MODE" in
  auto|full|segmented) ;;
  *) echo "XGuard: invalid deployment mode '$MODE'" >&2; exit 1 ;;
esac
ADOPT_EDGE=""
ADOPT_GATEWAY=""
if [ "$MODE" = full ] || { [ "$MODE" = auto ] && is_full_stack "${_profiles[@]}"; }; then
  ADOPT_EDGE="edge:50051"
  ADOPT_GATEWAY="host.docker.internal:50066"
fi

cat > "$ENV_FILE" <<EOF
XGUARD_COOKIE_INSECURE=false

XGUARD_DB_HOST=db
XGUARD_DB_PORT=5432
XGUARD_DB_USER=xguard
XGUARD_DB_PASSWORD=${DB_PASSWORD}
XGUARD_DB_NAME=xguard
POSTGRES_USER=xguard
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=xguard

XGUARD_CORE_TAG=${XGUARD_CORE_TAG}
XGUARD_PROXY_TAG=${XGUARD_PROXY_TAG}
XGUARD_GATEWAY_TAG=${XGUARD_GATEWAY_TAG}

XGUARD_ADOPT_EDGE=${ADOPT_EDGE}
XGUARD_ADOPT_GATEWAY=${ADOPT_GATEWAY}
EOF

chmod 600 "$ENV_FILE"
echo "XGuard: .env generated at ${ENV_FILE}"
