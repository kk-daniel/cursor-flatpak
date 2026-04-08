#!/bin/bash
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Extract version from the URL in the manifest (e.g., cursor_3.0.13_amd64.deb -> 3.0.13)
URL="$(grep -A 4 'filename: cursor.deb' co.anysphere.cursor.yaml | grep -o 'url: .*' | head -1 | cut -d' ' -f2)"

VERSION="$(echo "$URL" | sed -n 's/.*cursor_\([0-9]\+\.[0-9]\+\.[0-9]\+\)_.*/\1/p')"

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from URL: $URL"
    exit 1
fi

echo "Extracted version: $VERSION"

# Get current date in YYYY-MM-DD format
CURRENT_DATE="$(date +%Y-%m-%d)"

echo "Adding release $VERSION with date $CURRENT_DATE to metainfo.xml"

# Check if this version already exists in metainfo.xml
if grep -q "version=\"$VERSION\"" co.anysphere.cursor.metainfo.xml; then
    echo "Version $VERSION already exists in metainfo.xml, updating date..."
    # Update the date for existing version
    sed -i "s/<release version=\"$VERSION\" date=\"[^\"]*\"/<release version=\"$VERSION\" date=\"$CURRENT_DATE\"/" co.anysphere.cursor.metainfo.xml
else
    echo "Adding new version $VERSION to metainfo.xml..."
    # Add new release entry at the top of the releases section
    sed -i "/<releases>/a\\    <release version=\"$VERSION\" date=\"$CURRENT_DATE\"/>" co.anysphere.cursor.metainfo.xml
fi

echo "Metainfo updated successfully"
