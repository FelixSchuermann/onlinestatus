#!/bin/bash
# Install OnlineStatus2 to autostart on Linux Mint / Ubuntu / Debian
# Run this script from the project directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="onlinestatus2"
DESKTOP_FILE="$HOME/.config/autostart/${APP_NAME}.desktop"
APP_PATH="$SCRIPT_DIR/build/linux/x64/release/bundle/onlinestatus2"
ICON_PATH="$SCRIPT_DIR/assets/app_icon.png"

# Check if release build exists
if [ ! -f "$APP_PATH" ]; then
    echo "Error: Release build not found at $APP_PATH"
    echo "Run ./build-linux.sh first to build the app."
    exit 1
fi

# Create autostart directory if it doesn't exist
mkdir -p "$HOME/.config/autostart"

# Create the .desktop file
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Online Status
Comment=Track online status of friends
Exec=env LIBGL_ALWAYS_SOFTWARE=1 $APP_PATH
Icon=$ICON_PATH
Terminal=false
Categories=Network;Chat;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

echo "✓ Autostart entry created: $DESKTOP_FILE"
echo ""
echo "OnlineStatus2 will now start automatically when you log in."
echo ""
echo "To remove from autostart, run:"
echo "  rm \"$DESKTOP_FILE\""
echo ""
echo "To start the app now, run:"
echo "  ./run-linux.sh"

