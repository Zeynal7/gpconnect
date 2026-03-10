#!/bin/bash

INSTALL_DIR="$HOME/scripts"

echo "Uninstalling gpconnect..."
echo ""

# Remove files
rm -f "$INSTALL_DIR/gpconnect"
rm -rf "$INSTALL_DIR/GPConnectHelper.app"
rm -f "$INSTALL_DIR/.gpconnect_config"
rm -f "$INSTALL_DIR/.gpconnect_result"
rm -f "$INSTALL_DIR/.gpconnect_mode"
echo "Removed files from $INSTALL_DIR/"

# Remove Keychain entry
read -rp "Remove saved password from Keychain? (y/n): " remove_keychain
if [[ "$remove_keychain" =~ ^[Yy]$ ]]; then
    security delete-generic-password -s "GlobalProtect" > /dev/null 2>&1 && echo "Password removed from Keychain." || echo "No password found in Keychain."
fi

# Remove global symlink
if [ -L /usr/local/bin/gpconnect ]; then
    echo ""
    read -rp "Remove global symlink? (requires sudo) (y/n): " remove_symlink
    if [[ "$remove_symlink" =~ ^[Yy]$ ]]; then
        sudo rm -f /usr/local/bin/gpconnect
        echo "Symlink removed."
    fi
fi

# Remind about Accessibility
echo ""
echo "Don't forget to remove GPConnectHelper.app from Accessibility:"
echo "  System Settings → Privacy & Security → Accessibility"
read -rp "Open Accessibility settings now? (y/n): " open_settings
if [[ "$open_settings" =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi

echo ""
echo "Uninstall complete."
