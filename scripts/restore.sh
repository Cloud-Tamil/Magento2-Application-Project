#!/usr/bin/env bash
# ==============================================================================
# Enterprise Restore Script: MySQL Database & Magento Media Assets
# ==============================================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_db_dump.sql.gz> [path_to_media.tar.gz]"
    exit 1
fi

DB_FILE="$1"
MEDIA_FILE="${2:-}"

DB_NAME="${MYSQL_DATABASE:-magento2}"
DB_USER="${MYSQL_USER:-magento}"
DB_PASS="${MYSQL_PASSWORD:-magento_local_dev_pass123!}"

echo ">>> Starting Magento 2 Restore..."

if [ ! -f "${DB_FILE}" ]; then
    echo "Error: DB dump file not found at ${DB_FILE}"
    exit 1
fi

echo "Restoring database from ${DB_FILE}..."
gunzip -c "${DB_FILE}" | docker compose exec -T mysql mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
echo "Database restored successfully."

if [ -n "${MEDIA_FILE}" ] && [ -f "${MEDIA_FILE}" ]; then
    echo "Restoring media files from ${MEDIA_FILE}..."
    tar -xzf "${MEDIA_FILE}" -C src/pub/
    echo "Media files restored."
fi

echo "Flushing Magento cache..."
docker compose exec -u www-data magento bin/magento cache:flush || true
echo ">>> Restore complete!"
