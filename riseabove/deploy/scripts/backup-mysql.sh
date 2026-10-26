#!/usr/bin/env bash
# Dumps the Fleet database to /var/backups/riseabove-mdm and keeps 14 days of dumps.
# A dump is useless without FLEET_SERVER_PRIVATE_KEY from .env, so keep that backed up too.
# Copy dumps off the droplet as well (DigitalOcean droplet backups or a Spaces bucket).
set -euo pipefail
cd "$(dirname "$0")/.."

BACKUP_DIR=/var/backups/riseabove-mdm
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

out="$BACKUP_DIR/fleet-$(date +%Y%m%d-%H%M).sql.gz"
docker compose exec -T mysql sh -c \
  'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --set-gtid-purged=OFF fleet' \
  | gzip > "$out.tmp"
mv "$out.tmp" "$out"

find "$BACKUP_DIR" -name 'fleet-*.sql.gz' -mtime +14 -delete
echo "$(date -Is) wrote $out ($(du -h "$out" | cut -f1))"
