#!/bin/bash
# Update the manifest .deb checksums by verifying the GPG-signed apt repository index.
#
# Verification chain:
#   GPG key → InRelease signature → Packages checksum → .deb checksum
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

EXPECTED_FINGERPRINT="380FF4BCDC34A4BD92A3565342A1772E62E492D6"
KEY_URL="https://downloads.cursor.com/keys/anysphere.asc"
REPO_URL="https://downloads.cursor.com/aptrepo"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Download GPG key and InRelease
echo "Downloading GPG public key..."
wget -q -O "$TMPDIR/anysphere.asc" "$KEY_URL"

echo "Downloading InRelease..."
wget -q -O "$TMPDIR/InRelease" "$REPO_URL/dists/stable/InRelease"

# Import key and verify fingerprint
GNUPGHOME=$(mktemp -d -p "$TMPDIR")
export GNUPGHOME
gpg --import "$TMPDIR/anysphere.asc" >/dev/null 2>&1
FINGERPRINT=$(gpg --with-colons --list-public-keys 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
if [ "$FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]; then
    echo "ERROR: GPG key fingerprint mismatch!" >&2
    echo "  Expected: $EXPECTED_FINGERPRINT" >&2
    echo "  Got:      $FINGERPRINT" >&2
    exit 1
fi

# Verify InRelease GPG signature
echo "Verifying InRelease GPG signature..."
gpg --verify "$TMPDIR/InRelease"
echo "InRelease signature verified!"

update_arch() {
    local DEB_ARCH="$1"    # amd64, arm64
    local FLATPAK_ARCH="$2" # x86_64, aarch64

    # Extract expected Packages SHA256 from InRelease
    EXPECTED_PACKAGES_SHA256=$(awk -v arch="$DEB_ARCH" '
        /^SHA256:/ { in_sha256=1; next }
        /^[A-Z]/ && !/^ / { in_sha256=0 }
        in_sha256 && $0 ~ "main/binary-" arch "/Packages$" && !/\.gz$/ { print $1 }
    ' "$TMPDIR/InRelease")

    if [ -z "$EXPECTED_PACKAGES_SHA256" ]; then
        echo "ERROR: Could not find Packages SHA256 for $DEB_ARCH in InRelease" >&2
        exit 1
    fi

    # Download and verify Packages index
    echo "Downloading Packages index ($DEB_ARCH)..."
    wget -q -O "$TMPDIR/Packages-$DEB_ARCH" "$REPO_URL/dists/stable/main/binary-$DEB_ARCH/Packages"

    ACTUAL_PACKAGES_SHA256=$(sha256sum "$TMPDIR/Packages-$DEB_ARCH" | cut -d' ' -f1)
    if [ "$ACTUAL_PACKAGES_SHA256" != "$EXPECTED_PACKAGES_SHA256" ]; then
        echo "ERROR: Packages file checksum mismatch ($DEB_ARCH)!" >&2
        echo "  Expected: $EXPECTED_PACKAGES_SHA256" >&2
        echo "  Got:      $ACTUAL_PACKAGES_SHA256" >&2
        exit 1
    fi
    echo "Packages index verified ($DEB_ARCH)!"

    # Extract .deb info from Packages (stable cursor, not nightly)
    DEB_SHA256=$(awk '/^Package: cursor$/{p=1} p&&/^SHA256:/{print $2; exit}' "$TMPDIR/Packages-$DEB_ARCH")
    DEB_SIZE=$(awk '/^Package: cursor$/{p=1} p&&/^Size:/{print $2; exit}' "$TMPDIR/Packages-$DEB_ARCH")
    DEB_FILENAME=$(awk '/^Package: cursor$/{p=1} p&&/^Filename:/{print $2; exit}' "$TMPDIR/Packages-$DEB_ARCH")
    DEB_URL="$REPO_URL/$DEB_FILENAME"

    if [ -z "$DEB_SHA256" ] || [ -z "$DEB_SIZE" ] || [ -z "$DEB_FILENAME" ]; then
        echo "ERROR: Could not extract .deb info from Packages ($DEB_ARCH)" >&2
        exit 1
    fi

    echo "Verified .deb ($DEB_ARCH):"
    echo "  url: $DEB_URL"
    echo "  sha256: $DEB_SHA256"
    echo "  size: $DEB_SIZE"

    # Update manifest for this architecture
    SPEC="$(grep -B 1 -A 4 "only-arches: \[$FLATPAK_ARCH\]" co.anysphere.cursor.yaml | grep -A 4 'filename: cursor.deb')"
    OLD_URL="$(echo "$SPEC" | grep -o 'url: .*' | cut -d' ' -f2)"
    OLD_SHA256="$(echo "$SPEC" | grep -o 'sha256: .*' | head -1)"
    OLD_SIZE="$(echo "$SPEC" | grep -o 'size: .*')"

    sed -i \
        -e "s|$OLD_URL|$DEB_URL|" \
        -e "0,/$OLD_SHA256/s/$OLD_SHA256/sha256: $DEB_SHA256/" \
        -e "0,/$OLD_SIZE/s/$OLD_SIZE/size: $DEB_SIZE/" \
        co.anysphere.cursor.yaml

    echo ""
}

update_arch amd64 x86_64
update_arch arm64 aarch64

echo "Manifest updated!"
