#!/bin/bash
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Extract version from the URL in the manifest
SPEC="$(grep -A 3 'filename: appimage' co.anysphere.cursor.yaml)"
URL="$(echo "$SPEC" | grep -o 'url: .*' | cut -d' ' -f2)"

# Extract version from URL (e.g., Cursor-1.6.14-x86_64.AppImage -> 1.6.14)
VERSION="$(echo "$URL" | sed -n 's/.*Cursor-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-.*/\1/p')"

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