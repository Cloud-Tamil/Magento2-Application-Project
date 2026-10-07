#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Stack Health Check Script
# ==============================================================================

set -euo pipefail

echo "=========================================================================="
echo " RUNNING COMPREHENSIVE MAGENTO 2 DEVOPS HEALTH CHECK                      "
echo "=========================================================================="

FAILED=0

check() {
    local name="$1"
    local command="$2"
    printf "%-35s" "Checking ${name}..."
    if eval "$command" > /dev/null 2>&1; then
        echo -e "\033[0;32m[OK]\033[0m"
    else
        echo -e "\033[0;31m[FAILED]\033[0m"
        FAILED=1
    fi
}

# 1. Check Docker daemon & containers
check "Docker daemon" "docker info"
check "MySQL container" "docker compose exec -T mysql mysqladmin ping -h localhost -uroot -proot_local_dev_pass123!"
check "Redis container" "docker compose exec -T redis redis-cli ping"
check "OpenSearch container" "docker compose exec -T opensearch curl -s -f http://localhost:9200/_cat/health"
check "RabbitMQ container" "docker compose exec -T rabbitmq rabbitmq-diagnostics -q ping"
check "Nginx container" "docker compose exec -T nginx nginx -t"
check "PHP-FPM worker status" "docker compose exec -T magento php-fpm -t"

echo "--------------------------------------------------------------------------"
if [ $FAILED -eq 0 ]; then
    echo -e "\033[0;32mALL HEALTH CHECKS PASSED SUCCESSFULLY!\033[0m"
    exit 0
else
    echo -e "\033[0;31mONE OR MORE HEALTH CHECKS FAILED. Inspect with 'docker compose logs'.\033[0m"
    exit 1
fi
