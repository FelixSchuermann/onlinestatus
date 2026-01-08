#!/bin/bash
# Build Flutter Linux release using Docker
#
# Usage: ./build-linux.sh
#
# This script builds a Linux release of the Flutter app using Docker,
# which allows cross-compilation from Windows/Mac.

set -e

IMAGE_NAME="flutter-linux-builder"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get current user's UID and GID for permission fix
HOST_UID=$(id -u)
HOST_GID=$(id -g)

echo "=== Building Docker image for Flutter Linux compilation ==="
docker build -t "$IMAGE_NAME" -f Dockerfile.linux-build "$SCRIPT_DIR"

echo ""
echo "=== Building Flutter Linux release ==="
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "Mounting $SCRIPT_DIR to /app"

docker run --rm \
    -v "$SCRIPT_DIR:/app" \
    -w /app \
    "$IMAGE_NAME" \
    sh -c "echo '=== Container info ===' && pwd && echo '=== Mount check ===' && ls -la && echo '=== Building ===' && flutter pub get && flutter build linux --release && echo '=== Finding bundle ===' && find / -type d -name 'bundle' 2>/dev/null && echo '=== Checking /app/build ===' && ls -la /app/build/ 2>/dev/null || echo 'No /app/build' && echo '=== Checking ./build ===' && ls -la ./build/ 2>/dev/null || echo 'No ./build'"

echo ""
echo "=== Build complete ==="
echo "Output: build/linux/x64/release/bundle/"

# Check if build directory exists on host
if [ -d "build/linux/x64/release/bundle" ]; then
    echo "=== Files on host ==="
    ls -la build/linux/x64/release/bundle/
else
    echo "WARNING: Build directory not found on host!"
    echo "Checking build/ directory..."
    ls -la build/ 2>/dev/null || echo "build/ directory does not exist"
fi

