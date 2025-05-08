# Flatpak for Cursor

## Building and installing

1. `flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
2. `flatpak-builder --force-clean --user --install-deps-from=flathub --repo=repo --install builddir co.anysphere.cursor.yaml`
