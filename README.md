# Pelican Panel Docker

This repository builds and publishes Docker images for [Pelican Panel](https://github.com/pelican-dev/panel), providing both release and nightly builds.

## Docker Images

The Docker images are published to Google Artifact Registry:

```
us-docker.pkg.dev/pelican-gcr/pelican/panel
```

## Image Tags

### Release Builds

When a new release of Pelican Panel is published:

- `latest` - Always points to the most recent stable release
- `v1.0.0-beta21` - Specific version tag matching the Panel release tag

### Nightly Builds

Nightly builds are created automatically from the latest commit on the main branch:

- `nightly` - Always points to the most recent nightly build
- `commit-{SHA}` - Tagged with the exact Panel commit SHA (e.g., `commit-af9f2c653e2c0e4f0403afcc726059580ff824d4`)
- `nightly-{YYYYMMDD}` - Date-based tag for historical reference (e.g., `nightly-20240520`)

## Usage

### Using gcloud CLI:

```bash
gcloud artifacts docker tags list us-docker.pkg.dev/pelican-gcr/pelican/panel
```

### Using Docker Hub UI:

Visit the Google Artifact Registry UI at:
https://console.cloud.google.com/artifacts/docker/pelican-gcr/us/pelican/panel

### Pull the latest stable release:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

### Pull a specific version:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:v1.0.0-beta23
```

### Pull the latest nightly build:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:nightly
```

### Pull a specific nightly build by date:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:nightly-20250807
```

### Pull a specific commit:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:commit-af9f2c653e2c0e4f0403afcc726059580ff824d4
```

## View All Available Tags

You can view all available tags for this image using:

### Using gcloud CLI:

```bash
gcloud artifacts docker tags list us-docker.pkg.dev/pelican-gcr/pelican/panel
```

### Using Artifact Registry UI:

Visit the Google Artifact Registry UI at:
https://console.cloud.google.com/artifacts/docker/pelican-gcr/us/pelican/panel

## Build Process

The Docker images are built using GitHub Actions:

1. **Nightly builds** run automatically every day at midnight UTC
2. **Release builds** are triggered automatically when a new release is published in the Panel repository
3. **Manual builds** can be triggered from the GitHub Actions tab

## Configuration

The Docker image includes:

- FrankenPHP as the web server
- PHP 8.4 with all required extensions
- Node.js for frontend assets
- All Panel dependencies pre-installed

## License

This repository is licensed under the same license as Pelican Panel.

## Quick Start

To quickly test the Docker image with minimal configuration:

```bash
# Pull the latest image
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:latest

# Run with HTTPS (default)
docker run -p 8443:443 us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

You can access the panel at https://localhost:8443.

### Running with HTTP Only

If you prefer to run with HTTP only (no HTTPS):

```bash
docker run -p 8080:80 -e CADDY_PORT=80 us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

You can access the panel at http://localhost:8080.

### Configuration Options

The following environment variables can be used to customize the server:

- `CADDY_DOMAIN`: Domain name for the server (default: localhost)
- `CADDY_PORT`: Port to listen on (default: 443)
- `CADDY_GLOBAL_OPTS`: Additional Caddy global options, separated by semicolons

Example with custom options:

```bash
docker run -p 8443:443 \
  -e CADDY_DOMAIN=panel.example.com \
  -e CADDY_GLOBAL_OPTS="debug; log level INFO" \
  us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```
### All Environment Variables

The following environment variables can be configured:

#### Web Server Configuration
- `CADDY_DOMAIN`: Domain name for the server (default: localhost)
- `CADDY_PORT`: Port to listen on (default: 443)
- `CADDY_GLOBAL_OPTS`: Additional Caddy global options, separated by semicolons
- `ADMIN_EMAIL`: Email address for Let's Encrypt certificates (default: pelican@example.com)

#### Application Configuration
- `APP_ENV`: Application environment (default: production)
- `APP_DEBUG`: Enable debug mode (default: false)
- `APP_URL`: Application URL (default: http://localhost)
- `APP_KEY`: Laravel application key (auto-generated if not provided)

#### User Configuration
- `ADMIN_EMAIL`: Email for the default admin user (default: pelican@example.com)
- `ADMIN_USERNAME`: Username for the default admin user (default: pelican)
- `ADMIN_PASSWORD`: Password for the default admin user (default: pelican)

#### System Configuration
- `PUID`: User ID to run the application as (default: 1000)
- `PGID`: Group ID to run the application as (default: 1000)
- `TZ`: Timezone for the container (e.g., "America/New_York", "Europe/London")

### Container Paths

The container uses the following directory structure:

- `/pelican/app`: Application files (read-only)
- `/pelican/config`: Configuration files (should be persisted)
- `/pelican/data`: Application data (should be persisted)

For persistent data, mount volumes to the config and data directories:

```bash
docker run -p 8443:443 \
  -v pelican-config:/pelican/config \
  -v pelican-data:/pelican/data \
  us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

Important files in these directories:
- `/pelican/config/.env`: Laravel environment file
- `/pelican/config/Caddyfile`: Web server configuration
- `/pelican/data/database`: SQLite database location