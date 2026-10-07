#!/usr/bin/env bash
# ==============================================================================
# Full Local Development Environment Bootstrapper
# ==============================================================================

set -euo pipefail

echo ">>> Initializing Magento 2 Local Development Stack..."

# Check if .env exists, copy from .env.example if missing
if [ ! -f ".env" ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

# Ensure scripts are executable
chmod +x scripts/*.sh

# Create local Magento source folder structure if src is empty
mkdir -p src/app/etc src/pub/media src/pub/static src/var src/generated

# Fix permissions
./scripts/permissions.sh

# Build and start Docker services
echo ">>> Building and starting Docker Compose containers..."
docker compose build
docker compose up -d

echo ">>> Waiting for core services (MySQL, Redis, OpenSearch, RabbitMQ) to be healthy..."
timeout=120
elapsed=0
until docker compose ps | grep -q "healthy"; do
    if [ $elapsed -ge $timeout ]; then
        echo "Timed out waiting for services."
        exit 1
    fi
    sleep 3
    elapsed=$((elapsed + 3))
    echo "Waiting for health checks (${elapsed}s)..."
done

echo ">>> Stack is up and healthy! Run './scripts/install-magento.sh' to install Magento."
