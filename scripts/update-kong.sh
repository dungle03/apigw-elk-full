#!/usr/bin/env bash
set -euo pipefail

# Ensure .env exists, optionally set PUBLIC_IP, then render kong.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
RENDER_SCRIPT="$REPO_ROOT/scripts/render-kong.sh"

PUBLIC_IP_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--public-ip)
      shift
      PUBLIC_IP_ARG="${1:-}"
      if [[ -z "$PUBLIC_IP_ARG" ]]; then
        echo "Error: --public-ip requires a value" >&2
        exit 2
      fi
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--public-ip <IP_OR_DOMAIN>]" >&2
      exit 2
      ;;
  esac
  shift
done

# 1) Ensure .env exists
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created .env from .env.example. Please edit PUBLIC_IP if needed." >&2
  else
    echo "Creating minimal .env ..." >&2
    cat > "$ENV_FILE" <<'EOF'
# Global configuration
# Change this when your VPS IP changes
PUBLIC_IP=<YOUR_VPS_PUBLIC_IP_OR_DOMAIN>
EOF
    echo "Created minimal .env at $ENV_FILE. Update PUBLIC_IP before rendering if needed." >&2
  fi
fi

# 1b) Optionally set PUBLIC_IP from argument
if [[ -n "$PUBLIC_IP_ARG" ]]; then
  if grep -q "^\s*PUBLIC_IP\s*=" "$ENV_FILE"; then
    # portable sed in-place
    tmpfile="$(mktemp)"
    sed "s|^\s*PUBLIC_IP\s*=.*$|PUBLIC_IP=$PUBLIC_IP_ARG|" "$ENV_FILE" > "$tmpfile"
    mv "$tmpfile" "$ENV_FILE"
  else
    echo "PUBLIC_IP=$PUBLIC_IP_ARG" >> "$ENV_FILE"
  fi
  echo "PUBLIC_IP set to $PUBLIC_IP_ARG in .env" >&2
fi

# 1c) Report current PUBLIC_IP
set +e
CURRENT_IP=$(grep -E "^\s*PUBLIC_IP\s*=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | xargs)
set -e
if [[ -z "$CURRENT_IP" || "$CURRENT_IP" == *"<"*">"* ]]; then
  echo "Warning: PUBLIC_IP is not set to a concrete value in .env." >&2
else
  echo "Using PUBLIC_IP=$CURRENT_IP from .env" >&2
fi

# 2) Render kong.yml
if [[ ! -x "$RENDER_SCRIPT" ]]; then
  # Try to run even if not executable
  bash "$RENDER_SCRIPT"
else
  "$RENDER_SCRIPT"
fi

#echo "Done. kong/kong.yml has been rendered from template." >&2
