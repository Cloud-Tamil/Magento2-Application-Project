#!/usr/bin/env bash
# ==============================================================================
# Magento 2 File Ownership & Permission Standard
# ==============================================================================

set -euo pipefail

echo "Applying Magento 2 permission standards to src/..."

# Standard directory permissions: 775 for writable dirs, 755 for others
# Standard file permissions: 664 for writable files, 644 for others
if [ -d "src" ]; then
    find src/ -type d -exec chmod 755 {} + || true
    find src/ -type f -exec chmod 644 {} + || true
    
    mkdir -p src/var src/pub/static src/pub/media src/generated src/app/etc
    chmod -R 775 src/var src/pub/static src/pub/media src/generated src/app/etc || true

    if [ -f "src/bin/magento" ]; then
        chmod +x src/bin/magento
    fi
fi

# In Docker container
if docker compose ps | grep -q "magento2-app"; then
    echo "Setting ownership inside container..."
    docker compose exec -u root magento chown -R www-data:www-data /var/www/html/var /var/www/html/pub/static /var/www/html/pub/media /var/www/html/generated || true
    docker compose exec -u root magento chmod -R 775 /var/www/html/var /var/www/html/pub/static /var/www/html/pub/media /var/www/html/generated || true
fi

echo "Permissions updated successfully."
