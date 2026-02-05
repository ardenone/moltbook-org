#!/bin/bash
# Build script for moltbook-frontend that works around Longhorn PVC corruption
# This script builds the frontend in /tmp which uses tmpfs (in-memory filesystem)
# to avoid the overlay filesystem corruption issues with Longhorn PVCs

set -e

FRONTEND_DIR="/home/coder/Research/moltbook-org/moltbook-frontend"
BUILD_DIR="/tmp/moltbook-build"
LOCK_FILE="/tmp/moltbook-build.lock"

# Prevent concurrent builds
if [ -f "$LOCK_FILE" ]; then
    echo "Build already in progress. If this is stale, remove $LOCK_FILE"
    exit 1
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

echo "=== Building moltbook-frontend in /tmp to work around PVC corruption ==="
echo "Build directory: $BUILD_DIR"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy source files to /tmp (excluding node_modules, .next, etc.)
echo "Copying source files to /tmp..."
rsync -av \
    --exclude=node_modules \
    --exclude=.next \
    --exclude=.git \
    --exclude=core.* \
    --exclude=test-write \
    "$FRONTEND_DIR/" "$BUILD_DIR/"

# Install dependencies in /tmp (uses tmpfs - clean filesystem)
echo "Installing dependencies in /tmp..."
cd "$BUILD_DIR"
pnpm install

# Run tests
echo "Running tests..."
pnpm test

# Build the application
echo "Building application..."
pnpm run build

# Copy build artifacts back to source directory
echo "Copying build artifacts back to $FRONTEND_DIR..."
rm -rf "$FRONTEND_DIR/.next"
cp -r "$BUILD_DIR/.next" "$FRONTEND_DIR/"

# Copy lockfile back
cp "$BUILD_DIR/pnpm-lock.yaml" "$FRONTEND_DIR/"

echo "=== Build completed successfully ==="
echo "Build artifacts copied to $FRONTEND_DIR/.next"
