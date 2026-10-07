#!/usr/bin/env bash
# ==============================================================================
# Automated Magento 2 Production Setup Installer
# Configures MySQL, Redis (Cache/PageCache/Session), OpenSearch & RabbitMQ
# ==============================================================================

set -euo pipefail

# Load environment variables if .env exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "=========================================================================="
echo " Starting Magento 2.4.7 Automated Installation..."
echo "=========================================================================="

# Fallback defaults for local development
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-magento2}"
MYSQL_USER="${MYSQL_USER:-magento}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-magento_local_dev_pass123!}"

REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

OPENSEARCH_HOST="${OPENSEARCH_HOST:-opensearch}"
OPENSEARCH_PORT="${OPENSEARCH_PORT:-9200}"
OPENSEARCH_INDEX_PREFIX="${OPENSEARCH_INDEX_PREFIX:-magento2_local}"

RABBITMQ_HOST="${RABBITMQ_HOST:-rabbitmq}"
RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"
RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-guest}"
RABBITMQ_VHOST="${RABBITMQ_VHOST:-/}"

APP_URL="${APP_URL:-http://localhost:8080}"
MAGENTO_ADMIN_FIRSTNAME="${MAGENTO_ADMIN_FIRSTNAME:-DevOps}"
MAGENTO_ADMIN_LASTNAME="${MAGENTO_ADMIN_LASTNAME:-Admin}"
MAGENTO_ADMIN_EMAIL="${MAGENTO_ADMIN_EMAIL:-admin@example.com}"
MAGENTO_ADMIN_USERNAME="${MAGENTO_ADMIN_USERNAME:-devopsadmin}"
MAGENTO_ADMIN_PASSWORD="${MAGENTO_ADMIN_PASSWORD:-AdminPassword123!}"
MAGENTO_BACKEND_FRONTNAME="${MAGENTO_BACKEND_FRONTNAME:-admin_control}"
MAGENTO_LANGUAGE="${MAGENTO_LANGUAGE:-en_US}"
MAGENTO_CURRENCY="${MAGENTO_CURRENCY:-USD}"
MAGENTO_TIMEZONE="${MAGENTO_TIMEZONE:-UTC}"

echo "Step 1/5: Verifying dependency connectivity..."
docker compose exec magento php -r "
    \$conn = @fsockopen('${MYSQL_HOST}', ${MYSQL_PORT}, \$errno, \$errstr, 5);
    if (!\$conn) { echo 'Failed connecting to MySQL: ' . \$errstr . PHP_EOL; exit(1); }
    echo 'MySQL reachable at ${MYSQL_HOST}:${MYSQL_PORT}' . PHP_EOL;
"

echo "Step 2/5: Executing bin/magento setup:install..."
docker compose exec -u www-data magento bin/magento setup:install \
    --base-url="${APP_URL}/" \
    --db-host="${MYSQL_HOST}:${MYSQL_PORT}" \
    --db-name="${MYSQL_DATABASE}" \
    --db-user="${MYSQL_USER}" \
    --db-password="${MYSQL_PASSWORD}" \
    --admin-firstname="${MAGENTO_ADMIN_FIRSTNAME}" \
    --admin-lastname="${MAGENTO_ADMIN_LASTNAME}" \
    --admin-email="${MAGENTO_ADMIN_EMAIL}" \
    --admin-user="${MAGENTO_ADMIN_USERNAME}" \
    --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
    --language="${MAGENTO_LANGUAGE}" \
    --currency="${MAGENTO_CURRENCY}" \
    --timezone="${MAGENTO_TIMEZONE}" \
    --use-rewrites=1 \
    --backend-frontname="${MAGENTO_BACKEND_FRONTNAME}" \
    --search-engine=opensearch \
    --opensearch-host="${OPENSEARCH_HOST}" \
    --opensearch-port="${OPENSEARCH_PORT}" \
    --opensearch-index-prefix="${OPENSEARCH_INDEX_PREFIX}" \
    --opensearch-timeout=15 \
    --session-save=redis \
    --session-save-redis-host="${REDIS_HOST}" \
    --session-save-redis-port="${REDIS_PORT}" \
    --session-save-redis-db=2 \
    --session-save-redis-max-concurrency=20 \
    --cache-backend=redis \
    --cache-backend-redis-server="${REDIS_HOST}" \
    --cache-backend-redis-port="${REDIS_PORT}" \
    --cache-backend-redis-db=0 \
    --page-cache=redis \
    --page-cache-redis-server="${REDIS_HOST}" \
    --page-cache-redis-port="${REDIS_PORT}" \
    --page-cache-redis-db=1 \
    --amqp-host="${RABBITMQ_HOST}" \
    --amqp-port="${RABBITMQ_PORT}" \
    --amqp-user="${RABBITMQ_USER}" \
    --amqp-password="${RABBITMQ_PASSWORD}" \
    --amqp-virtualhost="${RABBITMQ_VHOST}" \
    --cleanup-database \
    --no-interaction

echo "Step 3/5: Compiling Dependency Injection..."
docker compose exec -u www-data magento bin/magento setup:di:compile

echo "Step 4/5: Deploying Static Content..."
docker compose exec -u www-data magento bin/magento setup:static-content:deploy -f en_US

echo "Step 5/5: Reindexing and Flushing Cache..."
docker compose exec -u www-data magento bin/magento indexer:reindex
docker compose exec -u www-data magento bin/magento cache:flush

echo "=========================================================================="
echo " INSTALLATION COMPLETE!"
echo " Storefront URL: ${APP_URL}"
echo " Admin Panel:    ${APP_URL}/${MAGENTO_BACKEND_FRONTNAME}"
echo " Admin User:     ${MAGENTO_ADMIN_USERNAME}"
echo " phpMyAdmin:     http://localhost:8081"
echo " RabbitMQ UI:    http://localhost:15672 (guest/guest)"
echo "=========================================================================="
