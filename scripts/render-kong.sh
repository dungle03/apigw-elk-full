#!/usr/bin/env bash
set -euo pipefail

# Render kong/kong.yml from kong/kong.yml.tmpl using PUBLIC_IP from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
TEMPLATE="$REPO_ROOT/kong/kong.yml.tmpl"
OUTPUT="$REPO_ROOT/kong/kong.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found at $ENV_FILE" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: template not found at $TEMPLATE" >&2
  exit 1
fi

# Load .env (supports simple KEY=VALUE lines)
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

if [[ -z "${PUBLIC_IP:-}" ]]; then
  echo "Error: PUBLIC_IP is not set in .env" >&2
  exit 1
fi

# Simple literal replacement for ${PUBLIC_IP}
# Using '|' as sed delimiter to avoid issues with dots in IP
sed "s|\${PUBLIC_IP}|$PUBLIC_IP|g" "$TEMPLATE" > "$OUTPUT"

echo "Rendered $TEMPLATE -> $OUTPUT using PUBLIC_IP=$PUBLIC_IP"
