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

# Add information about viewing all available tags if it doesn't exist
if ! grep -q "View all available tags" README.md; then
  # Find the position to insert the new section (after the Usage section)
  LINE_NUM=$(grep -n "^## Usage" README.md | cut -d: -f1)
  if [ -n "$LINE_NUM" ]; then
    # Find the next section after Usage
    NEXT_SECTION=$(tail -n +$LINE_NUM README.md | grep -n "^##" | head -n 2 | tail -n 1 | cut -d: -f1)
    if [ -n "$NEXT_SECTION" ]; then
      INSERT_LINE=$((LINE_NUM + NEXT_SECTION - 1))
      
      # Create the new section content
      NEW_SECTION="\n## View All Available Tags\n\nYou can view all available tags for this image using:\n\n### Using gcloud CLI:\n\n\`\`\`bash\ngcloud artifacts docker tags list us-docker.pkg.dev/pelican-gcr/pelican/panel\n\`\`\`\n\n### Using Docker Hub UI:\n\nVisit the Google Artifact Registry UI at:\nhttps://console.cloud.google.com/artifacts/docker/pelican-gcr/us/pelican/panel\n\n"
      
      # Insert the new section
      sed -i "${INSERT_LINE}i ${NEW_SECTION}" README.md
    fi
  fi
fi

echo "README.md has been updated with the latest image information"