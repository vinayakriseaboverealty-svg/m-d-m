#!/usr/bin/env bash
# Creates deploy/.env from env.example and fills every secret with a random value.
# Run once on the droplet. Then copy .env into the company password manager.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env already exists; refusing to overwrite it (it holds FLEET_SERVER_PRIVATE_KEY)." >&2
  exit 1
fi

umask 077
cp env.example .env

# Alphanumeric only, so values are safe in .env, YAML and HTTP headers.
random() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-"$1"; }
fill() { sed -i "s|^$1=\$|$1=$2|" .env; }

fill MYSQL_ROOT_PASSWORD "$(random 32)"
fill MYSQL_PASSWORD "$(random 32)"
fill FLEET_SERVER_PRIVATE_KEY "$(random 48)"
fill CLAUDE_OTEL_TOKEN "$(random 40)"
fill GRAFANA_ADMIN_PASSWORD "$(random 24)"

echo "Wrote $(pwd)/.env. Review the domains in it, then store a copy in the password manager."
