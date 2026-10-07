#!/usr/bin/env bash
# ==============================================================================
# Enterprise Backup Script: MySQL Database & Magento Media Assets
# ==============================================================================

set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "${BACKUP_DIR}"

DB_NAME="${MYSQL_DATABASE:-magento2}"
DB_USER="${MYSQL_USER:-magento}"
DB_PASS="${MYSQL_PASSWORD:-magento_local_dev_pass123!}"
DB_FILE="${BACKUP_DIR}/magento_db_${TIMESTAMP}.sql.gz"
MEDIA_FILE="${BACKUP_DIR}/magento_media_${TIMESTAMP}.tar.gz"

echo ">>> Starting Magento 2 Backup [${TIMESTAMP}]..."

# 1. Backup MySQL Database
echo "Dumping database ${DB_NAME}..."
docker compose exec -T mysql mysqldump \
    -u"${DB_USER}" \
    -p"${DB_PASS}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    "${DB_NAME}" | gzip > "${DB_FILE}"

echo "Database dumped to ${DB_FILE} ($(du -h "${DB_FILE}" | cut -f1))"

# 2. Backup Media Folder
if [ -d "src/pub/media" ]; then
    echo "Archiving media folder..."
    tar -czf "${MEDIA_FILE}" -C src/pub media/
    echo "Media archived to ${MEDIA_FILE} ($(du -h "${MEDIA_FILE}" | cut -f1))"
fi

echo ">>> Backup complete!"
