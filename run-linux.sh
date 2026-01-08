#!/bin/bash
# Run the Flutter Linux app with software rendering fallback
# This is needed for systems without proper OpenGL 3.0 support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/build/linux/x64/release/bundle/onlinestatus2"

# Check if debug build exists, use that instead
if [ -f "$SCRIPT_DIR/build/linux/x64/debug/bundle/onlinestatus2" ]; then
    APP_PATH="$SCRIPT_DIR/build/linux/x64/debug/bundle/onlinestatus2"
fi

# Force software rendering to avoid OpenGL issues
export LIBGL_ALWAYS_SOFTWARE=1

echo "Starting OnlineStatus with software rendering..."
exec "$APP_PATH" "$@"

