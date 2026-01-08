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

echo "=== Building Docker image for Flutter Linux compilation ==="
docker build -t "$IMAGE_NAME" -f Dockerfile.linux-build "$SCRIPT_DIR"

echo ""
echo "=== Building Flutter Linux release ==="
docker run --rm \
    -v "$SCRIPT_DIR:/app" \
    -w /app \
    "$IMAGE_NAME" \
    sh -c "flutter pub get && flutter build linux --release"

echo ""
echo "=== Build complete ==="
echo "Output: build/linux/x64/release/bundle/"

