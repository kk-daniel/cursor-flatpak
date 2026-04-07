#!/bin/bash
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

KEY_URL="https://downloads.cursor.com/keys/anysphere.asc"

SPEC="$(grep -A 3 'filename: appimage' co.anysphere.cursor.yaml)"
URL="$(echo "$SPEC" | grep -o 'url: .*' | cut -d' ' -f2)"
SIZE_LINE="$(echo "$SPEC" | grep -o 'size: .*')"
SHA256_LINE="$(echo "$SPEC" | grep -o 'sha256: .*')"

KEY_SPEC="$(grep -A 3 'filename: anysphere.asc' co.anysphere.cursor.yaml)"
KEY_SIZE_LINE="$(echo "$KEY_SPEC" | grep -o 'size: .*')"
KEY_SHA256_LINE="$(echo "$KEY_SPEC" | grep -o 'sha256: .*')"

echo "Updating checksum for $URL"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Download public key and AppImage
echo "Downloading GPG public key..."
wget -q -O "$TMPDIR/anysphere.asc" "$KEY_URL"

echo "Downloading AppImage..."
wget -q -O "$TMPDIR/appimage" "$URL"

# Verify GPG signature
echo "Verifying GPG signature..."
./verify-appimage.sh "$TMPDIR/appimage" "$TMPDIR/anysphere.asc"
echo "GPG signature verified!"

SIZE="$(wc -c < "$TMPDIR/appimage")"
SHA256="$(sha256sum "$TMPDIR/appimage" | cut -d' ' -f1)"
KEY_FILE_SIZE="$(wc -c < "$TMPDIR/anysphere.asc")"
KEY_FILE_SHA256="$(sha256sum "$TMPDIR/anysphere.asc" | cut -d' ' -f1)"

echo "appimage size: $SIZE"
echo "appimage sha256: $SHA256"
echo "key size: $KEY_FILE_SIZE"
echo "key sha256: $KEY_FILE_SHA256"

sed -i \
    -e "s/$SIZE_LINE/size: $SIZE/" \
    -e "s/$SHA256_LINE/sha256: $SHA256/" \
    -e "s/$KEY_SIZE_LINE/size: $KEY_FILE_SIZE/" \
    -e "s/$KEY_SHA256_LINE/sha256: $KEY_FILE_SHA256/" \
    co.anysphere.cursor.yaml
