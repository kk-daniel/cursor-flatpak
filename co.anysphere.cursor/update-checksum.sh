#!/bin/bash
set -e

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

SPEC="$(grep -A 3 'filename: appimage' co.anysphere.cursor.yaml)"

URL="$(echo "$SPEC" | grep -o 'url: .*' | cut -d' ' -f2)"
SIZE_LINE="$(echo "$SPEC" | grep -o 'size: .*')"
SHA256_LINE="$(echo "$SPEC" | grep -o 'sha256: .*')"

echo "Updating checksum for $URL"

rm -f appimage.tmp
wget -q -Oappimage.tmp "$URL"
SIZE="$(wc -c < appimage.tmp)"
SHA256="$(sha256sum appimage.tmp | cut -d' ' -f1)"
rm -f appimage.tmp

echo "size: $SIZE"
echo "sha256: $SHA256"

sed -i -e "s/$SIZE_LINE/size: $SIZE/" -e "s/$SHA256_LINE/sha256: $SHA256/" co.anysphere.cursor.yaml