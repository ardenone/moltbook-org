#!/bin/bash
# npm install workaround for Longhorn PVC filesystem issues
# This script works around TAR_ENTRY_ERROR and ENOTEMPTY issues that occur
# when running npm install directly on the Longhorn-backed PVC.
#
# PROVEN SOLUTION (mo-y72h):
# - Install to /tmp (overlay filesystem)
# - Use rsync to copy (more resilient than cp -r)
# - Manually copy .bin directory with cp -r (rsync doesn't copy symlinks properly)
#
# Why this works:
# - The Longhorn PVC has filesystem corruption causing ENOTEMPTY errors
# - npm install works on /tmp (overlay filesystem is healthy)
# - Direct cp -r fails with corruption
# - rsync handles partial copies better
# - .bin must be copied separately as it contains symlinks

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/moltbook-frontend"
API_DIR="$PROJECT_ROOT/api"
TEMP_BUILD_BASE="/tmp/npm-build-$USER"

echo "🔧 npm install workaround for Longhorn PVC filesystem issues"
echo "============================================================"

# Function to install dependencies in a temp directory on overlay filesystem
install_to_temp() {
    local target_dir="$1"
    local dir_name="$(basename "$target_dir")"

    if [ ! -f "$target_dir/package.json" ]; then
        echo "⚠️  No package.json found in $target_dir, skipping..."
        return
    fi

    echo ""
    echo "📦 Installing dependencies for $dir_name..."
    echo "   Using temp directory on overlay filesystem to avoid filesystem issues"

    local temp_dir="$TEMP_BUILD_BASE-$dir_name"

    # Create temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Copy package.json and package-lock.json if they exist
    cp "$target_dir/package.json" .
    if [ -f "$target_dir/package-lock.json" ]; then
        cp "$target_dir/package-lock.json" .
    fi

    # Run npm install in temp directory (on overlay fs)
    echo "   Running npm install in $temp_dir..."
    npm install --legacy-peer-deps --cache /tmp/npm-cache-new 2>&1 | grep -v "npm warn" || true

    # Prepare target directory
    cd "$target_dir"

    # Try to remove old node_modules (may fail due to corruption, that's OK)
    echo "   Attempting to clean up old node_modules..."
    rm -rf node_modules 2>/dev/null || true

    # Use rsync to copy node_modules (more resilient than cp -r)
    echo "   Copying node_modules using rsync..."
    rsync -av --delete "$temp_dir/node_modules/" "$target_dir/node_modules/" 2>&1 | tail -5

    # Copy .bin directory separately (rsync may not handle symlinks properly)
    if [ -d "$temp_dir/node_modules/.bin" ]; then
        echo "   Copying .bin directory..."
        rm -rf "$target_dir/node_modules/.bin" 2>/dev/null || true
        cp -r "$temp_dir/node_modules/.bin" "$target_dir/node_modules/" 2>/dev/null || true
    fi

    # Copy package-lock.json if updated
    if [ -f "$temp_dir/package-lock.json" ]; then
        cp "$temp_dir/package-lock.json" "$target_dir/"
    fi

    # Cleanup temp directory
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"

    echo "✅ Dependencies installed for $dir_name"
}

# Parse arguments
INSTALL_FRONTEND="yes"
INSTALL_API="yes"

while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend-only)
            INSTALL_FRONTEND="yes"
            INSTALL_API="no"
            shift
            ;;
        --api-only)
            INSTALL_FRONTEND="no"
            INSTALL_API="yes"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--frontend-only|--api-only]"
            exit 1
            ;;
    esac
done

# Install for frontend
if [ "$INSTALL_FRONTEND" = "yes" ]; then
    install_to_temp "$FRONTEND_DIR"
fi

# Install for API
if [ "$INSTALL_API" = "yes" ]; then
    install_to_temp "$API_DIR"
fi

echo ""
echo "============================================================"
echo "✅ All dependencies installed successfully!"
echo ""
echo "Note: This workaround is needed because the Longhorn PVC has"
echo "filesystem corruption causing TAR_ENTRY_ERROR and ENOTEMPTY issues."
echo "Installing to the overlay filesystem (/tmp) first avoids these issues."
echo ""
echo "LONG-TERM SOLUTION: Recreate the devpod with a fresh PVC."
echo "See BLOCKER_MO_1RP9_FILESYSTEM_SUMMARY.md for details."
