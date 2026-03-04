#!/bin/bash
set -e

BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="bluetech_sign_${DATE}.sql.gz"

mkdir -p "$BACKUP_DIR"

docker exec bts-prod-postgres pg_dump \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --no-password \
  | gzip > "${BACKUP_DIR}/${FILENAME}"

echo "Backup criado: ${BACKUP_DIR}/${FILENAME}"

ls -t "${BACKUP_DIR}"/*.sql.gz | tail -n +31 | xargs -r rm
echo "Backups antigos removidos"
