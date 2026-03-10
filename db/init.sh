#!/bin/bash
set -e
echo "🗄️  Running Valeris database migrations..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /docker-entrypoint-initdb.d/001_init.sql
echo "✅ Migrations completed."
