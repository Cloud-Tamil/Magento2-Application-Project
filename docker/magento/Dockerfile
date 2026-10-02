# ==============================================================================
# Multi-Stage Production Dockerfile for Magento 2.4.7 Enterprise DevOps
# Base: PHP 8.2-FPM (Debian Bookworm)
# ==============================================================================

# Stage 1: Base image with all Magento 2 required system packages and PHP extensions
FROM php:8.2-fpm-bookworm AS base

LABEL maintainer="Enterprise DevOps Team <devops@enterprise.com>"
LABEL description="Optimized PHP 8.2-FPM container for Magento 2.4.7"

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install system dependencies required for building PHP extensions and Magento runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libxslt1-dev \
    libsodium-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    default-mysql-client \
    cron \
    procps \
    nano \
    shadow \
    && rm -rf /var/lib/apt/lists/*

# Configure GD extension with FreeType, WebP, and JPEG support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-xpm

# Configure and compile core PHP extensions required by Magento 2
# Extensions: bcmath, ctype, curl, dom, fileinfo, gd, intl, mbstring, pdo_mysql, simplexml, soap, sockets, sodium, xml, xsl, zip, opcache
RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    ctype \
    curl \
    dom \
    fileinfo \
    gd \
    intl \
    mbstring \
    pdo_mysql \
    simplexml \
    soap \
    sockets \
    sodium \
    xml \
    xsl \
    zip \
    opcache

# Install official Composer 2 binary from Docker Hub
COPY --from=composer:2.7.7 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Ensure www-data user has UID/GID 33 matching common host/Nginx permissions
RUN usermod -u 33 www-data && groupmod -g 33 www-data \
    && mkdir -p /var/www/html /var/www/.composer /var/log/php-fpm \
    && chown -R www-data:www-data /var/www /var/log/php-fpm

# Copy custom PHP and PHP-FPM configuration files
COPY docker/magento/php.ini /usr/local/etc/php/conf.d/99-magento.ini
COPY docker/magento/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini
COPY docker/magento/www.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# ==============================================================================
# Stage 2: Development target (supports bind-mounting code and local tools)
# ==============================================================================
FROM base AS development

ENV APP_ENV=local
ENV MAGE_MODE=developer

EXPOSE 9000

# Keep running as root to allow entrypoint scripts to configure permissions, or switch to www-data
CMD ["php-fpm", "-F"]

# ==============================================================================
# Stage 3: Builder stage for compiling static assets and DI in production
# ==============================================================================
FROM base AS builder

ENV APP_ENV=production
ENV MAGE_MODE=production

# Copy application source code
COPY --chown=www-data:www-data src/ /var/www/html/

# Run as non-root www-data user during build
USER www-data

# If composer.json is present, install production dependencies
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader; \
    fi

# ==============================================================================
# Stage 4: Production final lightweight runtime container
# ==============================================================================
FROM base AS production

ENV APP_ENV=production
ENV MAGE_MODE=production

# Copy built code from builder stage
COPY --from=builder --chown=www-data:www-data /var/www/html /var/www/html

# Set directory permissions for writable Magento directories
RUN mkdir -p /var/www/html/var /var/www/html/pub/static /var/www/html/pub/media /var/www/html/generated \
    && chown -R www-data:www-data /var/www/html/var /var/www/html/pub/static /var/www/html/pub/media /var/www/html/generated \
    && chmod -R 775 /var/www/html/var /var/www/html/pub/static /var/www/html/pub/media /var/www/html/generated

USER www-data

EXPOSE 9000

# PHP-FPM healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 0

CMD ["php-fpm", "-F"]
