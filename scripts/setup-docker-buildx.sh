#!/bin/bash
# Setup Docker Build for Devpod Environment
#
# This script validates the Docker environment for building in containerized devpods.
# Due to overlay filesystem limitations in nested container environments, we use
# GitHub Actions for production builds and provide a dry-run mode for local testing.
#
# Usage:
#   ./scripts/setup-docker-buildx.sh

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

echo "========================================"
echo "Docker Build Environment Check"
echo "========================================"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Please install Docker first."
    exit 1
fi

log_success "Docker is available"

# Check if we're in a containerized environment (devpod)
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    log_warning "Running in containerized environment (devpod detected)"
    log_info "Note: Docker builds with BuildKit may fail due to nested overlay filesystem"
    log_info "For production builds, use GitHub Actions:"
    echo ""
    log_info "  gh workflow run build-push.yml"
    echo ""
fi

# Check Docker info
log_info "Docker version:"
docker --version

log_info "Docker Buildx version:"
docker buildx version

echo ""
echo "========================================"
log_success "Docker environment check complete!"
echo "========================================"
echo ""
log_info "Available build methods:"
echo "  1. GitHub Actions (recommended):"
echo "     gh workflow run build-push.yml"
echo ""
echo "  2. Local dry-run (limited in devpod):"
echo "     DOCKER_BUILDKIT=0 docker build -t test:latest ./api"
echo ""
log_info "Note: Due to overlay filesystem limitations in devpods,"
log_info "full Docker builds may not work. Use GitHub Actions for production."
echo ""
