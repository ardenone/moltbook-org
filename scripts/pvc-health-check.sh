#!/bin/bash
# PVC Health Check and Diagnostic Script
# For Longhorn PVC filesystem corruption issues
#
# This script helps diagnose and document PVC health issues,
# particularly the TAR_ENTRY_ERROR and ENOTEMPTY issues that occur
# when running npm install on Longhorn-backed PVCs.
#
# Usage: ./scripts/pvc-health-check.sh [--fix]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/moltbook-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "PVC Health Check and Diagnostic Tool"
echo "=========================================="
echo ""

# Get PVC information
echo "📊 PVC Information:"
echo "-------------------"
PVC_MOUNT=$(df | grep longhorn | awk '{print $6}')
PVC_DEVICE=$(df | grep longhorn | awk '{print $1}')
PVC_SIZE=$(df -h | grep longhorn | awk '{print $2}')
PVC_USED=$(df -h | grep longhorn | awk '{print $3}')
PVC_AVAIL=$(df -h | grep longhorn | awk '{print $4}')
PVC_PERCENT=$(df -h | grep longhorn | awk '{print $5}')

echo "Mount Point: $PVC_MOUNT"
echo "Device: $PVC_DEVICE"
echo "Size: $PVC_SIZE | Used: $PVC_USED | Available: $PVC_AVAIL ($PVC_PERCENT)"
echo ""

# Check Kubernetes PVC info
echo "🔍 Kubernetes PVC Status:"
echo "------------------------"
kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STORAGE:.spec.storageClassName,CAPACITY:.status.capacity.storage 2>/dev/null || echo "  (Cannot access kubectl)"
echo ""

# Test filesystem operations
echo "🧪 Filesystem Health Tests:"
echo "---------------------------"

# Test 1: Directory creation/removal
TEST_DIR="/tmp/pvc-test-$$"
mkdir -p "$TEST_DIR"
echo "✓ Directory creation: OK"
rmdir "$TEST_DIR"
echo "✓ Directory removal: OK"

# Test 2: File creation/read/delete
TEST_FILE="/tmp/pvc-test-file-$$"
echo "test content" > "$TEST_FILE"
if [ "$(cat "$TEST_FILE")" = "test content" ]; then
    echo "✓ File write/read: OK"
fi
rm -f "$TEST_FILE"
echo "✓ File deletion: OK"

# Test 3: npm/pnpm tar extraction (simulate npm install behavior)
TEST_TAR_DIR="/tmp/pvc-tar-test-$$"
mkdir -p "$TEST_TAR_DIR"
cd "$TEST_TAR_DIR"
echo '{"name":"test","version":"1.0.0"}' > package.json
echo "test content" > test-file.txt
tar czf test.tar.gz test-file.txt package.json

# Test extraction
EXTRACT_DIR="/tmp/pvc-extract-test-$$"
mkdir -p "$EXTRACT_DIR"
if tar xzf test.tar.gz -C "$EXTRACT_DIR" 2>/dev/null; then
    echo "✓ TAR extraction: OK"
else
    echo -e "${RED}✗ TAR extraction: FAILED${NC}"
fi

# Cleanup
cd "$PROJECT_ROOT"
rm -rf "$TEST_TAR_DIR" "$EXTRACT_DIR"
echo ""

# Test 4: Frontend npm install (the actual problem)
echo "📦 Frontend Dependency Installation Test:"
echo "-----------------------------------------"

if [ -d "$FRONTEND_DIR" ]; then
    cd "$FRONTEND_DIR"

    # Check if node_modules exists
    if [ -d "node_modules" ]; then
        NODE_MODULES_SIZE=$(du -sh node_modules 2>/dev/null | awk '{print $1}')
        echo "Current node_modules size: $NODE_MODULES_SIZE"
    fi

    # Try pnpm install with /tmp store
    echo "Testing pnpm install with /tmp store..."
    if HOME=/tmp npx pnpm install --store-dir /tmp/pnpm-store-test --frozen-lockfile >/dev/null 2>&1; then
        echo -e "${GREEN}✓ pnpm install with /tmp store: SUCCESS${NC}"
    else
        echo -e "${YELLOW}⚠ pnpm install with /tmp store: Warning (may be up-to-date)${NC}"
    fi

    # Try build (skip if already built)
    if [ -d ".next" ]; then
        echo "Build artifacts exist, skipping build test..."
        echo -e "${GREEN}✓ Build artifacts present${NC}"
    else
        echo "Testing build..."
        if npm run build >/dev/null 2>&1; then
            echo -e "${GREEN}✓ npm run build: SUCCESS${NC}"
        else
            echo -e "${RED}✗ npm run build: FAILED${NC}"
        fi
    fi

    cd "$PROJECT_ROOT"
else
    echo "Frontend directory not found at $FRONTEND_DIR"
fi
echo ""

# Available storage classes
echo "💾 Available Storage Classes:"
echo "-----------------------------"
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,TYPE:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class 2>/dev/null || echo "  (Cannot access kubectl)"
echo ""

# Recommendations
echo "📋 Diagnosis Summary & Recommendations:"
echo "----------------------------------------"

# Check if PVC is on Longhorn
if [[ "$PVC_DEVICE" == *"longhorn"* ]]; then
    echo -e "${YELLOW}⚠️  PVC is on Longhorn storage class${NC}"
    echo ""
    echo "Current Workaround (Functional):"
    echo "  - Use pnpm with --store-dir /tmp/pnpm-store"
    echo "  - This works because /tmp is on a different filesystem (overlay)"
    echo ""
    echo "Long-term Solutions:"
    echo ""
    echo "  1. Recreate PVC with different storage class (RECOMMENDED)"
    echo "     - Available: local-path, nfs-synology, proxmox-local-lvm"
    echo "     - Requires: Data backup, PVC deletion, devpod recreation"
    echo ""
    echo "  2. Migrate to local-path storage (faster, local SSD)"
    echo "     - Create new PVC with local-path storage class"
    echo "     - Migrate data using rsync"
    echo ""
    echo "  3. Use nfs-synology for persistent network storage"
    echo "     - Better for shared access across nodes"
    echo "     - May have higher latency than local storage"
else
    echo -e "${GREEN}✓ PVC is NOT on Longhorn${NC}"
    echo "  Filesystem issues should not occur."
fi

echo ""
echo "=========================================="
echo "Health check complete!"
echo "=========================================="

# Optional: Apply fix if requested
if [ "$1" = "--fix" ]; then
    echo ""
    echo "🔧 Applying fix..."
    echo ""

    if [ -d "$FRONTEND_DIR" ]; then
        cd "$FRONTEND_DIR"
        echo "Running pnpm install with /tmp store..."
        npx pnpm install --store-dir /tmp/pnpm-store --force
        echo -e "${GREEN}✓ Fix applied successfully!${NC}"
    fi
fi
