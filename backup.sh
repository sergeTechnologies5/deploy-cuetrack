#!/usr/bin/env bash
# Nightly Postgres backup. Cron: 0 3 * * * /opt/cuetrack/deploy/backup.sh
set -euo pipefail
cd "$(dirname "$0")"
source .env
DIR=../backups
mkdir -p "$DIR"
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U "$DB_USER" -d iot-dashboard | gzip > "$DIR/db-$(date +%F).sql.gz"
find "$DIR" -name 'db-*.sql.gz' -mtime +7 -delete
