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

### Pull the latest stable release:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

### Pull a specific version:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:v1.0.0-beta21
```

### Pull the latest nightly build:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:nightly
```

### Pull a specific nightly build by date:

```bash
docker pull us-docker.pkg.dev/pelican-gcr/pelican/panel:nightly-20240520
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

# Run with minimal configuration (data will not persist)
docker run -p 8443:443 us-docker.pkg.dev/pelican-gcr/pelican/panel:latest
```

This will start the container and expose it on ports 80 and 443. You can access the panel at https://localhost:8443.
