# syntax=docker/dockerfile:1
# Pelican Production Dockerfile using FrankenPHP

# ================================
# Stage 0: Clone the repository
# ================================
FROM alpine:latest AS clone

WORKDIR /clone

# Install git
RUN apk add --no-cache git

# Clone the repository (default to main branch, can be overridden with build args)
ARG REPO_URL=https://github.com/pelican-dev/panel.git
ARG REPO_BRANCH=main
ARG REPO_COMMIT=HEAD

# Clone the repository
RUN git clone --depth 1 ${REPO_URL} .

# Checkout specific branch or tag
RUN if [ "$REPO_BRANCH" != "main" ]; then git checkout ${REPO_BRANCH}; fi

# If a specific commit or tag is specified, checkout that reference
RUN if [ "$REPO_COMMIT" != "HEAD" ]; then git fetch --depth 1 origin ${REPO_COMMIT} && git checkout ${REPO_COMMIT}; fi

# ================================
# Stage 1-1: Composer Install
# ================================
FROM php:8.4-alpine AS composer

WORKDIR /build

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install required PHP extensions for Composer
RUN apk add --no-cache \
    $PHPIZE_DEPS \
    git \
    unzip \
    libzip-dev \
    icu-dev \
    libpng-dev \
    libxml2-dev \
    oniguruma-dev \
    && docker-php-ext-install \
    bcmath \
    gd \
    intl \
    zip \
    opcache \
    pcntl \
    pdo_mysql \
    mbstring

# Copy composer files from the cloned repository
COPY --from=clone /clone/composer.json /clone/composer.lock ./

# Install dependencies with --ignore-platform-reqs to bypass extension checks
RUN composer install --no-dev --no-interaction --no-autoloader --no-scripts --ignore-platform-reqs

# ================================
# Stage 1-2: Yarn Install
# ================================
FROM node:24-slim AS yarn

WORKDIR /build

# Copy package files from the cloned repository
COPY --from=clone /clone/package.json /clone/yarn.lock ./

RUN yarn config set network-timeout 300000 \
    && yarn install --frozen-lockfile

# ================================
# Stage 2-1: Composer Optimize
# ================================
FROM composer AS composerbuild

# Copy full code from the cloned repository
COPY --from=clone /clone ./

RUN composer dump-autoload --optimize

# ================================
# Stage 2-2: Build Frontend Assets
# ================================
FROM yarn AS yarnbuild

WORKDIR /build

# Copy full code from the cloned repository
COPY --from=clone /clone ./
COPY --from=composer /build .

RUN yarn run build

# ================================
# Stage 2-3: Build PHP Extensions
# ================================
FROM dunglas/frankenphp:1-php8.4-alpine AS phpextensions

# Install build dependencies and compile PHP extensions
RUN apk update && apk add --no-cache \
    icu-dev \
    libzip-dev \
    libpng-dev \
    libxml2-dev \
    oniguruma-dev \
    && docker-php-ext-install \
    bcmath \
    gd \
    intl \
    zip \
    opcache \
    pcntl \
    pdo_mysql \
    mbstring

# ================================
# Stage 3: Build Final Application Image
# ================================
FROM dunglas/frankenphp:1-php8.4-alpine AS final

# Copy PHP extensions from the phpextensions stage
COPY --from=phpextensions /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=phpextensions /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Install only runtime dependencies
RUN apk update && apk add --no-cache \
    ca-certificates \
    curl \
    supercronic \
    su-exec \
    libzip \
    libpng \
    icu-libs \
    libxml2

# Set environment variables for paths
ENV PELICAN_HOME=/pelican \
    PELICAN_APP=/pelican/app \
    PELICAN_CONFIG=/pelican/config \
    PELICAN_DATA=/pelican/data

# Create abc user and group
RUN addgroup -g 1000 abc && \
    adduser -D -u 1000 -G abc -h "$PELICAN_HOME" abc

# Create directory structure
RUN mkdir -p "$PELICAN_APP" "$PELICAN_CONFIG" "$PELICAN_DATA" \
    "$PELICAN_DATA/database" "$PELICAN_APP/storage/logs" "$PELICAN_APP/bootstrap/cache"

WORKDIR $PELICAN_APP

# Copy application files
COPY --chown=abc:abc --chmod=750 --from=composerbuild /build .
COPY --chown=abc:abc --chmod=750 --from=yarnbuild /build/public ./public

# Copy Docker configuration files
COPY --chown=abc:abc --chmod=644 docker.d/Caddyfile "$PELICAN_APP/Caddyfile.template"
COPY --chown=abc:abc --chmod=644 docker.d/crontab /etc/supercronic/crontab
COPY --chown=root:root --chmod=755 docker.d/entrypoint.sh /entrypoint.sh

# Set permissions and create necessary directories
RUN mkdir -p /etc/supercronic \
    # Symlink to config and data paths
    && ln -s "$PELICAN_CONFIG/.env" ./.env \
    && ln -s "$PELICAN_CONFIG/Caddyfile" ./Caddyfile \
    && ln -s "$PELICAN_DATA/database/database.sqlite" ./database/database.sqlite \
    # Make sure directories and files have proper permissions
    && chmod -R 750 "$PELICAN_HOME" "$PELICAN_CONFIG" "$PELICAN_DATA" \
    && chown -R abc:abc "$PELICAN_HOME" "$PELICAN_CONFIG" "$PELICAN_DATA" \
    && chmod -R 755 ./vendor

HEALTHCHECK --interval=5m --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

EXPOSE 80 443

VOLUME $PELICAN_DATA
VOLUME $PELICAN_CONFIG

ENTRYPOINT ["/entrypoint.sh"]
CMD ["frankenphp", "run"]