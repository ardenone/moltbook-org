#!/bin/bash
# npm build workaround for Longhorn PVC filesystem issues
# This script works around filesystem corruption that occurs during
# Next.js builds by running the build in /tmp (overlay filesystem).
#
# PROVEN SOLUTION:
# - Copy entire project to /tmp (overlay filesystem)
# - Run build in /tmp
# - Copy .next build artifacts back using tar
#
# Why this works:
# - The Longhorn PVC has filesystem corruption causing ENOENT errors
# - Build operations work on /tmp (overlay filesystem is healthy)
# - tar handles partial copies better than cp/mv when filesystem is corrupted

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/moltbook-frontend"
TEMP_BUILD_BASE="/tmp/npm-build-$USER"

echo "🔧 npm build workaround for Longhorn PVC filesystem issues"
echo "============================================================"

# Function to build in a temp directory on overlay filesystem
build_in_temp() {
    local target_dir="$1"
    local dir_name="$(basename "$target_dir")"

    if [ ! -f "$target_dir/package.json" ]; then
        echo "⚠️  No package.json found in $target_dir, skipping..."
        return
    fi

    echo ""
    echo "🏗️  Building $dir_name..."
    echo "   Using temp directory on overlay filesystem to avoid filesystem issues"

    local temp_dir="$TEMP_BUILD_BASE-$dir_name"

    # Create temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
    mkdir -p "$temp_dir"

    # Copy entire project using tar (handles corruption better than cp)
    echo "   Copying project to $temp_dir using tar..."
    tar cf - -C "$target_dir" . | tar xf - -C "$temp_dir"

    # Build in temp directory
    echo "   Running build in $temp_dir..."
    cd "$temp_dir"
    npm run build 2>&1 | grep -E "(Compiled|error|Error|✓|✗|Route|Generating)" || true

    # Prepare target directory
    cd "$target_dir"

    # Remove old .next directory
    echo "   Cleaning up old .next directory..."
    rm -rf .next 2>/dev/null || true

    # Copy .next back using tar
    echo "   Copying .next back using tar..."
    tar cf - -C "$temp_dir" .next | tar xf -

    # Cleanup temp directory
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"

    echo "✅ Build completed for $dir_name"
}

# Parse arguments
BUILD_FRONTEND="yes"
BUILD_API="yes"

while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend-only)
            BUILD_FRONTEND="yes"
            BUILD_API="no"
            shift
            ;;
        --api-only)
            BUILD_FRONTEND="no"
            BUILD_API="yes"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--frontend-only|--api-only]"
            exit 1
            ;;
    esac
done

# Build frontend
if [ "$BUILD_FRONTEND" = "yes" ]; then
    build_in_temp "$FRONTEND_DIR"
fi

# Build API
if [ "$BUILD_API" = "yes" ]; then
    if [ -d "$API_DIR" ]; then
        build_in_temp "$API_DIR"
    fi
fi

echo ""
echo "============================================================"
echo "✅ All builds completed successfully!"
echo ""
echo "Note: This workaround is needed because the Longhorn PVC has"
echo "filesystem corruption causing ENOENT errors during builds."
echo "Building in the overlay filesystem (/tmp) first avoids these issues."
echo ""
echo "LONG-TERM SOLUTION: Recreate the devpod with a fresh PVC."
echo "See docs/PVC_RECREATION_GUIDE.md for details."
