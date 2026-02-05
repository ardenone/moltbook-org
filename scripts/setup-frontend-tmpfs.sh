#!/bin/bash
# Frontend Build Fix - Longhorn PVC Filesystem Corruption
# This script mounts node_modules and .next on tmpfs to bypass filesystem corruption
# Usage: Run from moltbook-frontend directory or source from bashrc.d
#
# BEAD: mo-9i6t - Fix: Longhorn PVC filesystem corruption blocking npm installs

set -e

FRONTEND_DIR="/home/coder/Research/moltbook-org/moltbook-frontend"
STORE_DIR="/tmp/pnpm-store-clean"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we're already set up
check_mounted() {
    mount | grep -q "$FRONTEND_DIR/node_modules.*tmpfs"
}

# Unmount existing mounts (if any)
unmount_existing() {
    log_info "Unmounting any existing tmpfs mounts..."
    mount | grep "$FRONTEND_DIR/node_modules" | awk '{print $3}' | \
        xargs -I {} sudo umount {} 2>/dev/null || true
    mount | grep "$FRONTEND_DIR/.next" | awk '{print $3}' | \
        xargs -I {} sudo umount {} 2>/dev/null || true
    sleep 1
}

# Setup node_modules on tmpfs
setup_node_modules() {
    log_info "Setting up node_modules on tmpfs..."

    if [ -d "$FRONTEND_DIR/node_modules" ]; then
        if check_mounted; then
            log_info "node_modules already on tmpfs, skipping..."
        else
            log_warn "Removing existing node_modules directory..."
            rm -rf "$FRONTEND_DIR/node_modules"
        fi
    fi

    mkdir -p "$FRONTEND_DIR/node_modules"
    sudo mount -t tmpfs -o size=16G,nr_inodes=2M,nodev,nosuid tmpfs "$FRONTEND_DIR/node_modules"
    sudo chown coder:coder "$FRONTEND_DIR/node_modules"
    log_info "node_modules mounted on tmpfs (16GB)"
}

# Setup .next on tmpfs
setup_next_build() {
    log_info "Setting up .next on tmpfs..."

    if [ -d "$FRONTEND_DIR/.next" ]; then
        mount | grep -q "$FRONTEND_DIR/.next.*tmpfs" && return 0
        log_warn "Removing existing .next directory..."
        rm -rf "$FRONTEND_DIR/.next"
    fi

    mkdir -p "$FRONTEND_DIR/.next"
    sudo mount -t tmpfs -o size=8G,nr_inodes=1M,nodev,nosuid tmpfs "$FRONTEND_DIR/.next"
    sudo chown coder:coder "$FRONTEND_DIR/.next"
    log_info ".next mounted on tmpfs (8GB)"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies with clean store..."

    # Check if already installed
    if [ -f "$FRONTEND_DIR/node_modules/next/package.json" ]; then
        log_info "Dependencies already installed, skipping..."
        return 0
    fi

    cd "$FRONTEND_DIR"
    pnpm install --store-dir="$STORE_DIR" --force
    log_info "Dependencies installed successfully"
}

# Main execution
main() {
    echo "========================================="
    echo "Frontend Build Fix - tmpfs Setup"
    echo "========================================="
    echo ""

    unmount_existing
    setup_node_modules
    setup_next_build
    install_dependencies

    echo ""
    echo "========================================="
    log_info "Setup complete!"
    echo "========================================="
    echo ""
    echo "Mounted directories:"
    mount | grep "$FRONTEND_DIR" | grep tmpfs
    echo ""
    echo "To build:"
    echo "  cd $FRONTEND_DIR"
    echo "  pnpm run build"
    echo ""
    log_warn "Note: tmpfs mounts are NOT persistent across pod restarts"
    log_warn "Run this script again after pod restart"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
