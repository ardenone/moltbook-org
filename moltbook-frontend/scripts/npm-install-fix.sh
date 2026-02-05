#!/bin/bash
# npm/pnpm Install Fix for Longhorn PVC Filesystem Corruption
# This script works around filesystem corruption on Longhorn PVC by:
# 1. Installing dependencies to a temporary filesystem (/tmp)
# 2. Using tar to transfer files (handles corruption better than cp/mv)
# 3. Providing verification steps

set -e

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="/tmp/moltbook-install-$$"
STORE_DIR="/tmp/pnpm-store-$$"

echo "========================================="
echo "Longhorn PVC Filesystem Corruption Fix"
echo "========================================="
echo "Frontend Dir: $FRONTEND_DIR"
echo "Temp Dir: $TEMP_DIR"
echo ""

# Step 1: Clean temp directory
echo "[1/5] Setting up temporary directory..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Step 2: Copy package files
echo "[2/5] Copying package files..."
cp "$FRONTEND_DIR/package.json" "$TEMP_DIR/"
if [ -f "$FRONTEND_DIR/pnpm-lock.yaml" ]; then
    cp "$FRONTEND_DIR/pnpm-lock.yaml" "$TEMP_DIR/"
fi
if [ -f "$FRONTEND_DIR/.npmrc" ]; then
    cp "$FRONTEND_DIR/.npmrc" "$TEMP_DIR/"
fi

# Step 3: Install to temp directory
echo "[3/5] Installing dependencies to temporary filesystem..."
cd "$TEMP_DIR"
npx pnpm install --store-dir="$STORE_DIR" --force

# Step 4: Backup existing node_modules and transfer new one
echo "[4/5] Transferring node_modules..."
cd "$FRONTEND_DIR"

# Move existing to corrupted backup
if [ -d "node_modules" ]; then
    echo "Backing up existing node_modules to node_modules.corrupted..."
    rm -rf "node_modules.corrupted"
    mv "node_modules" "node_modules.corrupted" 2>/dev/null || true
    # If move failed, try removing it
    if [ -d "node_modules" ]; then
        echo "Removing corrupted node_modules..."
        rm -rf "node_modules" 2>/dev/null || true
    fi
fi

# Use tar to transfer (handles corruption better than cp/mv)
echo "Transferring via tar..."
tar cf - -C "$TEMP_DIR" node_modules 2>/dev/null | tar xf - || {
    echo "ERROR: tar transfer failed. Filesystem corruption may be too severe."
    echo "Consider devpod recreation."
    exit 1
}

# Step 5: Verify installation
echo "[5/5] Verifying installation..."
if [ -d "node_modules" ] && [ -d "node_modules/next" ]; then
    SIZE=$(du -sh node_modules 2>/dev/null | cut -f1)
    echo "✓ node_modules transferred successfully ($SIZE)"
    echo "✓ Build should now work with: pnpm run build:next"
else
    echo "✗ Verification failed. node_modules incomplete."
    exit 1
fi

# Cleanup
echo ""
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR" "$STORE_DIR"

echo ""
echo "========================================="
echo "Fix completed successfully!"
echo "========================================="
echo ""
echo "To verify the fix:"
echo "  cd $FRONTEND_DIR"
echo "  pnpm run build:next"
echo ""
echo "Note: This is a workaround. The Longhorn PVC should be recreated"
echo "to prevent future filesystem corruption issues."
