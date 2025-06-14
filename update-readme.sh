#!/bin/bash
set -e

# This script updates the README.md with the latest image information
# It should be run after a successful build in the GitHub workflow

# Get the latest release tag and commit
LATEST_RELEASE=$(cat .last_built_release 2>/dev/null || echo "unknown")
LATEST_COMMIT=$(cat .last_built_commit 2>/dev/null || echo "unknown")

# Get the current date in YYYYMMDD format for the nightly tag
CURRENT_DATE=$(date +'%Y%m%d')

# Update the README with the latest information
sed -i "s/docker pull us-docker\.pkg\.dev\/pelican-gcr\/pelican\/panel:v[0-9]\+\.[0-9]\+\.[0-9]\+-\?[a-zA-Z0-9]*/docker pull us-docker.pkg.dev\/pelican-gcr\/pelican\/panel:${LATEST_RELEASE}/g" README.md
sed -i "s/docker pull us-docker\.pkg\.dev\/pelican-gcr\/pelican\/panel:nightly-[0-9]\+/docker pull us-docker.pkg.dev\/pelican-gcr\/pelican\/panel:nightly-${CURRENT_DATE}/g" README.md
sed -i "s/docker pull us-docker\.pkg\.dev\/pelican-gcr\/pelican\/panel:commit-[a-zA-Z0-9]\+\.\.\./docker pull us-docker.pkg.dev\/pelican-gcr\/pelican\/panel:commit-${LATEST_COMMIT}/" README.md

# Also update the example in the Image Tags section
sed -i "s/commit-{SHA}\" - Tagged with the exact Panel commit SHA (e\.g\., \`commit-[a-zA-Z0-9]\+\.\.\.\`)/commit-{SHA}\" - Tagged with the exact Panel commit SHA (e.g., \`commit-${LATEST_COMMIT}\`)/" README.md

echo "README.md has been updated with the latest image information"