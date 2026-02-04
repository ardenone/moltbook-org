#!/bin/bash
# Moltbook Image Build Helper - GitHub Actions Trigger
#
# Due to overlay filesystem limitations in devpod/containerized environments,
# Docker builds may fail. This script triggers GitHub Actions to build images
# externally and provides status monitoring.
#
# Usage:
#   ./scripts/build-images-devpod.sh [OPTIONS]
#
# Options:
#   --watch         Watch the build progress
#   --api-only      Build only the API image
#   --frontend-only Build only the Frontend image
#   --help          Show this help message
#
# Examples:
#   ./scripts/build-images-devpod.sh                # Trigger build and exit
#   ./scripts/build-images-devpod.sh --watch        # Trigger build and watch progress
#   ./scripts/build-images-devpod.sh --api-only     # Build only API

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
DO_WATCH=false
BUILD_API=true
BUILD_FRONTEND=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --watch)
      DO_WATCH=true
      shift
      ;;
    --api-only)
      BUILD_FRONTEND=false
      shift
      ;;
    --frontend-only)
      BUILD_API=false
      shift
      ;;
    --help)
      sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not found. Please install it from: https://cli.github.com/"
        exit 1
    fi

    # Check authentication
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    fi

    log_success "GitHub CLI is authenticated"

    # Check if we're in the right directory
    if [[ ! -f "${PROJECT_ROOT}/api/Dockerfile" ]]; then
        log_error "API Dockerfile not found at ${PROJECT_ROOT}/api/Dockerfile"
        exit 1
    fi

    if [[ ! -f "${PROJECT_ROOT}/moltbook-frontend/Dockerfile" ]]; then
        log_error "Frontend Dockerfile not found at ${PROJECT_ROOT}/moltbook-frontend/Dockerfile"
        exit 1
    fi

    log_success "Project structure validated"
}

# Trigger GitHub Actions workflow
trigger_build() {
    log_info "Triggering GitHub Actions workflow..."

    # Trigger the build-push workflow
    if gh workflow run build-push.yml; then
        log_success "Workflow triggered successfully"
    else
        log_error "Failed to trigger workflow"
        exit 1
    fi

    # Get the latest run
    sleep 2  # Give GitHub a moment to register the run
    LATEST_RUN=$(gh run list --workflow=build-push.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")

    if [ -n "$LATEST_RUN" ]; then
        log_info "Run ID: $LATEST_RUN"
        log_info "View at: https://github.com/ardenone/moltbook-org/actions/runs/$LATEST_RUN"
    fi
}

# Watch the build progress
watch_build() {
    log_info "Watching build progress..."
    echo ""

    if gh run watch 2>/dev/null; then
        echo ""
        log_success "Build completed!"
    else
        echo ""
        log_warning "Watch command exited. Check status manually:"
        log_info "  gh run list --workflow=build-push.yml"
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "Moltbook Image Build (via GitHub Actions)"
    echo "========================================"
    echo ""
    log_info "Why GitHub Actions?"
    log_info "  Docker builds in devpod fail due to nested overlay filesystem issues."
    log_info "  GitHub Actions provides a clean build environment without this limitation."
    echo ""

    check_prerequisites
    echo ""

    trigger_build
    echo ""

    if [[ "$DO_WATCH" == "true" ]]; then
        watch_build
    else
        log_info "Build is running in GitHub Actions."
        echo ""
        log_info "To watch the build:"
        echo "  gh run watch"
        echo ""
        log_info "To check status:"
        echo "  gh run list --workflow=build-push.yml"
        echo ""
        log_info "To view logs:"
        echo "  gh run view <run-id> --log"
    fi

    echo ""
    echo "========================================"
    log_info "Images will be available at:"
    echo "  - ghcr.io/ardenone/moltbook-api:latest"
    echo "  - ghcr.io/ardenone/moltbook-frontend:latest"
    echo "========================================"
}

main "$@"
