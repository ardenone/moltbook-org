#!/bin/bash
# npm install workaround for Longhorn PVC filesystem issues
# This script works around TAR_ENTRY_ERROR and ENOTEMPTY issues that occur
# when running npm install directly on the Longhorn-backed PVC.

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
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Copy package.json
    cp "$target_dir/package.json" .

    # Run npm install in temp directory (on overlay fs)
    echo "   Running npm install in $temp_dir..."
    npm install --legacy-peer-deps

    # Remove old node_modules from target
    echo "   Cleaning up old node_modules..."
    rm -rf "$target_dir/node_modules"

    # Move new node_modules to target
    echo "   Moving node_modules to $target_dir..."
    mv "$temp_dir/node_modules" "$target_dir/"

    # Copy package-lock.json if it was generated
    if [ -f "package-lock.json" ]; then
        cp "$temp_dir/package-lock.json" "$target_dir/"
    fi

    # Cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"

    echo "✅ Dependencies installed for $dir_name"
}

# Install for frontend
install_to_temp "$FRONTEND_DIR"

# Install for API
install_to_temp "$API_DIR"

echo ""
echo "============================================================"
echo "✅ All dependencies installed successfully!"
echo ""
echo "Note: This workaround is needed because the Longhorn PVC has"
echo "issues with npm's tar extraction operations (TAR_ENTRY_ERROR)."
echo "Installing to the overlay filesystem first avoids these issues."
