#!/usr/bin/env bash
set -euo pipefail

# Determine repo root (parent of this script's directory)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_PATH="${REPO_ROOT}/.env"

KONG_TEMPLATE_PATH="${REPO_ROOT}/kong/kong.yml.tmpl"
KONG_OUTPUT_PATH="${REPO_ROOT}/kong/kong.yml"

AUTH_TEMPLATE_PATH="${REPO_ROOT}/usersvc/src/auth.service.ts.tmpl"
AUTH_OUTPUT_PATH="${REPO_ROOT}/usersvc/src/auth.service.ts"

if [[ ! -f "${ENV_PATH}" ]]; then
  echo ".env not found at ${ENV_PATH}" >&2
  exit 1
fi

# Load .env as simple KEY=VALUE (ignore comments/empty lines)
declare -A VARS
while IFS='=' read -r key val; do
  key="$(echo "$key" | xargs)"
  val="$(echo "$val" | xargs)"
  [[ -z "$key" ]] && continue
  [[ "$key" =~ ^# ]] && continue
  # Strip surrounding quotes
  if [[ "$val" =~ ^\".*\"$ || "$val" =~ ^\'.*\'$ ]]; then
    val="${val:1:${#val}-2}"
  fi
  VARS["$key"]="$val"
done < "${ENV_PATH}"

if [[ -z "${VARS[PUBLIC_IP]:-}" ]]; then
  echo "PUBLIC_IP not found in .env" >&2
  exit 1
fi

PUBLIC_IP="${VARS[PUBLIC_IP]}"
echo "Using PUBLIC_IP=${PUBLIC_IP} from .env"

KEYCLOAK_REALM_BASE="http://${PUBLIC_IP}:8080/realms/demo"

# Simple template renderer: replace ${VAR} literally
render_template() {
  local template_path="$1"
  local output_path="$2"
  local description="$3"

  if [[ ! -f "${template_path}" ]]; then
    echo "Template not found: ${template_path}" >&2
    return 1
  fi

  local content
  content="$(< "${template_path}")"

  # Core vars
  content="${content//\$\{PUBLIC_IP\}/${PUBLIC_IP}}"
  content="${content//\$\{KEYCLOAK_REALM_BASE\}/${KEYCLOAK_REALM_BASE}}"

  printf "%s" "${content}" > "${output_path}"
  if [[ -n "${description}" ]]; then
    echo "Rendered ${description}: ${template_path} -> ${output_path}"
  else
    echo "Rendered: ${template_path} -> ${output_path}"
  fi
}

# 1) Render kong.yml from template
render_template "${KONG_TEMPLATE_PATH}" "${KONG_OUTPUT_PATH}" "kong/kong.yml"

# 2) Render usersvc/src/auth.service.ts (KEYCLOAK_REALM_BASE)
if [[ -f "${AUTH_TEMPLATE_PATH}" ]]; then
  render_template "${AUTH_TEMPLATE_PATH}" "${AUTH_OUTPUT_PATH}" "usersvc/src/auth.service.ts"
else
  echo "auth.service.ts.tmpl not found, skipping AuthService render."
fi

echo "All render steps completed."
