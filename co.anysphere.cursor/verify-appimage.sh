#!/bin/sh
# Verify the GPG signature embedded in a Cursor AppImage.
# Usage: verify-appimage.sh <appimage> <pubkey>
#
# Follows the AppImageKit signing algorithm:
# https://github.com/AppImage/AppImageKit/blob/master/src/validate.c
set -e

EXPECTED_FINGERPRINT="380FF4BCDC34A4BD92A3565342A1772E62E492D6"

APPIMAGE="$1"
PUBKEY="$2"

if [ -z "$APPIMAGE" ] || [ -z "$PUBKEY" ]; then
    echo "Usage: verify-appimage.sh <appimage> <pubkey>" >&2
    exit 1
fi

# Set up temporary GPG home directory
GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

# Import public key and verify fingerprint
gpg --import "$PUBKEY" >/dev/null 2>&1
FINGERPRINT=$(gpg --with-colons --list-public-keys 2>/dev/null | grep '^fpr:' | head -1 | cut -d: -f10)
if [ "$FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]; then
    echo "ERROR: GPG key fingerprint mismatch!" >&2
    echo "  Expected: $EXPECTED_FINGERPRINT" >&2
    echo "  Got:      $FINGERPRINT" >&2
    exit 1
fi

# Parse ELF section offsets for .sha256_sig and .sig_key
eval $(objdump -h "$APPIMAGE" | awk '
    /\.sha256_sig/ { printf "SIG_OFFSET=0x%s\nSIG_SIZE=0x%s\n", $6, $3 }
    /\.sig_key/    { printf "KEY_SIZE=0x%s\n", $3 }
')
SIG_OFFSET=$((SIG_OFFSET))
SIG_SIZE=$((SIG_SIZE))
KEY_SIZE=$((KEY_SIZE))
SKIP_LEN=$((SIG_SIZE + KEY_SIZE))

# Extract GPG signature (using dd to avoid objcopy which truncates AppImage files)
dd if="$APPIMAGE" bs=1 skip=$SIG_OFFSET count=$SIG_SIZE 2>/dev/null \
    | tr -d '\0' > "$GNUPGHOME/sig.asc"

# Compute SHA256 digest with signature sections zeroed out
{
    dd if="$APPIMAGE" iflag=count_bytes count=$SIG_OFFSET bs=4096 2>/dev/null
    dd if=/dev/zero iflag=count_bytes count=$SKIP_LEN bs=4096 2>/dev/null
    dd if="$APPIMAGE" iflag=skip_bytes skip=$((SIG_OFFSET + SKIP_LEN)) bs=4096 2>/dev/null
} | sha256sum | cut -d' ' -f1 | tr -d '\n' > "$GNUPGHOME/digest.txt"

# Verify GPG signature
gpg --verify "$GNUPGHOME/sig.asc" "$GNUPGHOME/digest.txt"
