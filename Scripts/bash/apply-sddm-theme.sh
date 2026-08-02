#!/usr/bin/env bash

# This script applies an SDDM theme from a user's directory to the system directory.
# It is intended to be run with pkexec.

set -euo pipefail

if [[ -z "$1" ]]; then
    echo "Usage: $0 <path-to-theme>"
    exit 1
fi

SRC_THEME="$1"
DEST_DIR="/usr/share/sddm/themes/hydra"
CONF_FILE="/etc/sddm.conf.d/99-hydra.conf"

if [[ ! -d "$SRC_THEME" ]]; then
    echo "Error: Theme directory $SRC_THEME does not exist."
    exit 1
fi

echo "Applying SDDM theme from $SRC_THEME to $DEST_DIR..."

# Create destination if it doesn't exist
mkdir -p /usr/share/sddm/themes
mkdir -p /etc/sddm.conf.d

# Clean old theme
rm -rf "$DEST_DIR"

# Copy new theme
cp -a "$SRC_THEME" "$DEST_DIR"

# Ensure permissions so SDDM can read it
chown -R root:root "$DEST_DIR"
chmod -R a+rX "$DEST_DIR"

# Write config
cat << 'EOF' > "$CONF_FILE"
[Theme]
Current=hydra
EOF

echo "SDDM theme applied successfully."
