#!/bin/bash
set -e

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
  echo "Uso: ./restore-db.sh /caminho/para/backup.sql.gz"
  exit 1
fi

echo "ATENCAO: isso vai sobrescrever o banco atual. Confirma? (y/N)"
read -r confirm
if [ "$confirm" != "y" ]; then
  exit 0
fi

gunzip -c "$BACKUP_FILE" | docker exec -i bts-prod-postgres psql \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB"

echo "Banco restaurado com sucesso"
