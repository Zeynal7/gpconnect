#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/scripts"

echo "Installing gpconnect..."
echo ""

# Check for Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo "Swift compiler not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Create scripts directory
mkdir -p "$INSTALL_DIR"

# Copy script files
cp "$SCRIPT_DIR/gpconnect" "$INSTALL_DIR/gpconnect"
chmod +x "$INSTALL_DIR/gpconnect"

# Build Swift helper app
REBUILD=false
if [ "$1" = "--rebuild" ]; then
    REBUILD=true
    rm -rf "$INSTALL_DIR/GPConnectHelper.app"
fi

if [ -d "$INSTALL_DIR/GPConnectHelper.app" ] && [ "$REBUILD" = false ]; then
    echo "GPConnectHelper.app already exists — skipping build. Use --rebuild to force."
else
    echo "Building GPConnectHelper.app..."
    mkdir -p "$INSTALL_DIR/GPConnectHelper.app/Contents/MacOS"
    if ! swiftc -o "$INSTALL_DIR/GPConnectHelper.app/Contents/MacOS/GPConnectHelper" \
        "$SCRIPT_DIR/Sources/main.swift" -framework AppKit; then
        echo "Build failed."
        rm -rf "$INSTALL_DIR/GPConnectHelper.app"
        exit 1
    fi

    cat > "$INSTALL_DIR/GPConnectHelper.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.gpconnect.helper</string>
    <key>CFBundleName</key>
    <string>GPConnectHelper</string>
    <key>CFBundleExecutable</key>
    <string>GPConnectHelper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSBackgroundOnly</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>GPConnect needs to control GlobalProtect to connect/disconnect VPN.</string>
</dict>
</plist>
EOF
    codesign --force --sign - "$INSTALL_DIR/GPConnectHelper.app" 2>/dev/null
    echo "Built GPConnectHelper.app"
fi

echo ""

# Accessibility permission
echo "GPConnectHelper.app needs Accessibility permission to control GlobalProtect."
read -rp "Open Accessibility settings now? (y/n): " open_settings
if [[ "$open_settings" =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    echo ""
    echo "  → Click '+' and add: $INSTALL_DIR/GPConnectHelper.app"
    echo ""
    read -rp "Press Enter once you've added it..."
fi

echo ""

# Global symlink
read -rp "Make 'gpconnect' available globally? (requires sudo) (y/n): " make_global
if [[ "$make_global" =~ ^[Yy]$ ]]; then
    sudo ln -sf "$INSTALL_DIR/gpconnect" /usr/local/bin/gpconnect
    echo "Symlink created. You can run 'gpconnect' from anywhere."
else
    echo "You can run it with: $INSTALL_DIR/gpconnect"
    echo "Or add ~/scripts to your PATH: export PATH=\"\$HOME/scripts:\$PATH\""
fi

echo ""
echo "Setup complete! Run 'gpconnect' — first run will prompt for your username and password."
