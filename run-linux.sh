#!/bin/bash
# Run the Flutter Linux app with software rendering fallback
# This is needed for systems without proper OpenGL 3.0 support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer release build, fallback to debug
if [ -f "$SCRIPT_DIR/build/linux/x64/release/bundle/onlinestatus2" ]; then
    APP_PATH="$SCRIPT_DIR/build/linux/x64/release/bundle/onlinestatus2"
elif [ -f "$SCRIPT_DIR/build/linux/x64/debug/bundle/onlinestatus2" ]; then
    APP_PATH="$SCRIPT_DIR/build/linux/x64/debug/bundle/onlinestatus2"
else
    echo "Error: No build found. Run ./build-linux.sh first."
    exit 1
fi

# Force software rendering to avoid OpenGL issues on older hardware
export LIBGL_ALWAYS_SOFTWARE=1

echo "Starting OnlineStatus ($APP_PATH) with software rendering..."
exec "$APP_PATH" "$@"

