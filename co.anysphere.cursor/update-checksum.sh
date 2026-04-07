#!/bin/bash
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

EXPECTED_FINGERPRINT="380FF4BCDC34A4BD92A3565342A1772E62E492D6"
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

# Download and verify GPG public key
echo "Downloading GPG public key..."
wget -q -O "$TMPDIR/anysphere.asc" "$KEY_URL"

gpg --no-default-keyring --keyring "$TMPDIR/anysphere.gpg" --import "$TMPDIR/anysphere.asc" 2>/dev/null
FINGERPRINT=$(gpg --no-default-keyring --keyring "$TMPDIR/anysphere.gpg" --with-colons --list-public-keys 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
if [ "$FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]; then
    echo "ERROR: GPG key fingerprint mismatch!" >&2
    echo "  Expected: $EXPECTED_FINGERPRINT" >&2
    echo "  Got:      $FINGERPRINT" >&2
    exit 1
fi
echo "Key fingerprint verified: $FINGERPRINT"

KEY_FILE_SHA256="$(sha256sum "$TMPDIR/anysphere.asc" | cut -d' ' -f1)"
KEY_FILE_SIZE="$(wc -c < "$TMPDIR/anysphere.asc")"

# Download AppImage
echo "Downloading AppImage..."
wget -q -O "$TMPDIR/appimage" "$URL"
SIZE="$(wc -c < "$TMPDIR/appimage")"
SHA256="$(sha256sum "$TMPDIR/appimage" | cut -d' ' -f1)"

# Verify GPG signature
echo "Verifying GPG signature..."
eval $(objdump -h "$TMPDIR/appimage" | awk '
    /\.sha256_sig/ { printf "SIG_OFFSET=0x%s\nSIG_SIZE=0x%s\n", $6, $3 }
    /\.sig_key/    { printf "KEY_SECTION_SIZE=0x%s\n", $3 }
')
SIG_OFFSET=$((SIG_OFFSET))
SIG_SIZE=$((SIG_SIZE))
KEY_SECTION_SIZE=$((KEY_SECTION_SIZE))
SKIP_LEN=$((SIG_SIZE + KEY_SECTION_SIZE))

# Extract signature using dd (objcopy truncates AppImage files)
dd if="$TMPDIR/appimage" bs=1 skip=$SIG_OFFSET count=$SIG_SIZE 2>/dev/null \
    | tr -d '\0' > "$TMPDIR/sig.asc"

{
    dd if="$TMPDIR/appimage" iflag=count_bytes count=$SIG_OFFSET bs=4096 2>/dev/null
    dd if=/dev/zero iflag=count_bytes count=$SKIP_LEN bs=4096 2>/dev/null
    dd if="$TMPDIR/appimage" iflag=skip_bytes skip=$((SIG_OFFSET + SKIP_LEN)) bs=4096 2>/dev/null
} | sha256sum | cut -d' ' -f1 | tr -d '\n' > "$TMPDIR/digest.txt"

gpg --no-default-keyring --keyring "$TMPDIR/anysphere.gpg" --verify "$TMPDIR/sig.asc" "$TMPDIR/digest.txt"
echo "GPG signature verified!"

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
