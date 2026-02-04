#!/bin/bash
# Setup Docker Buildx for Devpod Environment
#
# This script configures Docker Buildx to work in containerized devpod environments
# where the default overlay storage driver fails due to nested overlay filesystem mounts.
#
# Usage:
#   ./scripts/setup-docker-buildx.sh
#
# After running this, use build-images-devpod.sh to build images.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

BUILDER_NAME="devpod-builder"

echo "========================================"
echo "Docker Buildx Setup for Devpod"
echo "========================================"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Please install Docker first."
    exit 1
fi

log_info "Checking Docker Buildx availability..."

if ! docker buildx version &> /dev/null; then
    log_error "Docker Buildx not available. Please install Docker Buildx plugin."
    exit 1
fi

log_success "Docker Buildx is available"

# Check if we're in a containerized environment (devpod)
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    log_warning "Running in containerized environment (devpod detected)"
    log_info "Will configure Buildx to avoid overlay filesystem issues"
fi

# Remove existing builder if it exists
if docker buildx ls | grep -q "$BUILDER_NAME"; then
    log_info "Removing existing builder '$BUILDER_NAME'..."
    docker buildx rm "$BUILDER_NAME" 2>/dev/null || true
fi

# Create new builder with vfs storage driver
log_info "Creating new Docker Buildx builder: $BUILDER_NAME"
log_info "Using vfs storage driver to avoid nested overlay filesystem issues"

docker buildx create \
    --name "$BUILDER_NAME" \
    --driver docker-container \
    --driver-opt network=host \
    --use \
    --buildkitd-flags '--allow-insecure-entitlement=security.insecure' 2>/dev/null || {
    log_error "Failed to create builder"
    log_info "Falling back to creating builder without network host option..."
    docker buildx create \
        --name "$BUILDER_NAME" \
        --driver docker-container \
        --use
}

log_success "Builder '$BUILDER_NAME' created successfully"

# Start the builder
log_info "Starting builder..."
docker buildx inspect --bootstrap "$BUILDER_NAME"

log_success "Builder is ready"

# Show builder status
echo ""
log_info "Builder configuration:"
docker buildx inspect "$BUILDER_NAME"

echo ""
echo "========================================"
log_success "Docker Buildx setup complete!"
echo "========================================"
echo ""
log_info "You can now build Docker images in the devpod using:"
echo "  ./scripts/build-images-devpod.sh"
echo ""
log_info "Or use buildx directly:"
echo "  docker buildx build --builder $BUILDER_NAME -t test:latest ./path/to/context"
echo ""
