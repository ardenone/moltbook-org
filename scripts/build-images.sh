#!/bin/bash
# Moltbook Container Image Build Script
# Builds and pushes API and Frontend images to ghcr.io
#
# IMPORTANT: This script will NOT work in devpod/containerized environments due to
# overlay filesystem limitations. Docker/Podman cannot build images inside containers.
#
# RECOMMENDED: Use GitHub Actions workflow instead (.github/workflows/build-images.yml)
# which builds on GitHub's Ubuntu runners with native Docker support.
#
# ALTERNATIVE: For local builds, run this script from a non-containerized environment
# (your local machine, a VM, or a physical server with Docker/Podman installed).
#
# KUBERNETES ALTERNATIVE: See scripts/build-with-kaniko.yml for kaniko-based builds.
#
# Usage:
#   ./scripts/build-images.sh [OPTIONS]
#
# Options:
#   --dry-run       Build images without pushing to registry
#   --push          Push images to registry (requires GITHUB_TOKEN)
#   --api-only      Build only the API image
#   --frontend-only Build only the Frontend image
#   --tag TAG       Use specific tag instead of 'latest'
#   --force         Bypass container environment check (experimental)
#   --help          Show this help message
#
# Examples:
#   ./scripts/build-images.sh --dry-run                    # Build only, don't push
#   ./scripts/build-images.sh --push                       # Build and push
#   GITHUB_TOKEN=xxx ./scripts/build-images.sh --push      # With explicit token
#   ./scripts/build-images.sh --push --tag v1.0.0          # Build with specific tag
#   ./scripts/build-images.sh --force --push               # Force build in devpod

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY="ghcr.io"
ORGANIZATION="ardenone"
API_IMAGE_NAME="${REGISTRY}/${ORGANIZATION}/moltbook-api"
FRONTEND_IMAGE_NAME="${REGISTRY}/${ORGANIZATION}/moltbook-frontend"
DEFAULT_TAG="${IMAGE_TAG:-latest}"

# Parse arguments
DRY_RUN=false
DO_PUSH=false
BUILD_API=true
BUILD_FRONTEND=true
TAG="$DEFAULT_TAG"
FORCE_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --push)
      DO_PUSH=true
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
    --tag)
      TAG="$2"
      shift 2
      ;;
    --force)
      FORCE_BUILD=true
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

  # Check if running in a containerized environment
  if [[ -f /.dockerenv ]] || grep -qa docker /proc/1/cgroup 2>/dev/null; then
    if [[ "$FORCE_BUILD" == "true" ]]; then
      log_warning "=========================================="
      log_warning "WARNING: Running inside a containerized environment!"
      log_warning "=========================================="
      log_warning "Build forced with --force flag. Proceeding at your own risk."
      log_warning "Build may fail due to overlay filesystem limitations."
      log_warning ""
    else
      log_error "=========================================="
      log_error "ERROR: Running inside a Docker container!"
      log_error "=========================================="
      log_error ""
      log_error "Docker/Podman cannot build images inside containers due to overlay"
      log_error "filesystem limitations (nested overlayfs is not supported)."
      log_error ""
      log_error "RECOMMENDED SOLUTIONS:"
      log_error "  1. Use GitHub Actions: .github/workflows/build-images.yml (automatic on push)"
      log_error "  2. Build locally from your machine (not from devpod/container)"
      log_error "  3. Use kaniko: kubectl apply -f scripts/build-with-kaniko.yml"
      log_error ""
      log_error "To force build anyway (experimental), use: --force"
      log_error "To build images, run this script from a non-containerized environment:"
      log_error "  - Your local machine with Docker/Podman installed"
      log_error "  - A VM or physical server"
      log_error "  - GitHub Actions runner (automatic workflow)"
      log_error ""
      log_error "See documentation for more details."
      exit 1
    fi
  fi

  # Check for podman or docker
  if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
  elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
  else
    log_error "Neither podman nor docker found. Please install one of them."
    exit 1
  fi
  log_success "Using container runtime: $CONTAINER_CMD"

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

# Authenticate to registry
authenticate() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "Dry run mode: Skipping authentication"
    return
  fi

  if [[ "$DO_PUSH" == "false" ]]; then
    log_info "Push not requested: Skipping authentication"
    return
  fi

  log_info "Authenticating to ${REGISTRY}..."

  # Check for GITHUB_TOKEN
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log_error "GITHUB_TOKEN environment variable not set"
    log_error ""
    log_error "To authenticate with ghcr.io, you need to provide a GitHub Personal Access Token."
    log_error ""
    log_error "OPTIONS:"
    log_error "  1. Set environment variable: export GITHUB_TOKEN=your_token_here"
    log_error "  2. Pass inline: GITHUB_TOKEN=your_token $0 --push"
    log_error "  3. Mount Kubernetes secret (see docs/github-token-setup.md)"
    log_error ""
    log_error "Create a token at: https://github.com/settings/tokens"
    log_error "Required scopes: write:packages, read:packages"
    log_error ""
    log_error "For detailed setup instructions, see: docs/github-token-setup.md"
    exit 1
  fi

  # Authenticate using echo to pipe the token
  echo "$GITHUB_TOKEN" | $CONTAINER_CMD login "${REGISTRY}" --username "${GITHUB_USERNAME:-github}" --password-stdin

  if [[ $? -eq 0 ]]; then
    log_success "Authenticated to ${REGISTRY}"
  else
    log_error "Authentication failed"
    log_error "Verify your GITHUB_TOKEN has the correct scopes: write:packages, read:packages"
    exit 1
  fi
}

# Build a single image
build_image() {
  local name="$1"
  local dockerfile="$2"
  local context="$3"
  local image_tag="${name}:${TAG}"

  log_info "Building ${image_tag}..."
  log_info "  Context: ${context}"
  log_info "  Dockerfile: ${dockerfile}"

  # Build arguments
  local build_args=(
    "--file" "${dockerfile}"
    "--tag" "${image_tag}"
    "--tag" "${name}:latest"
  )

  # Add build labels
  build_args+=(
    "--label" "org.opencontainers.image.source=https://github.com/ardenone/moltbook-org"
    "--label" "org.opencontainers.image.created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    "--label" "org.opencontainers.image.revision=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
  )

  # Build
  if $CONTAINER_CMD build "${build_args[@]}" "${context}"; then
    log_success "Built ${image_tag}"
  else
    log_error "Failed to build ${image_tag}"
    exit 1
  fi

  # Show image size
  local image_size=$($CONTAINER_CMD images "${name}:latest" --format "{{.Size}}")
  log_info "Image size: ${image_size}"
}

# Push a single image
push_image() {
  local name="$1"
  local image_tag="${name}:${TAG}"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "Dry run mode: Skipping push of ${image_tag}"
    return
  fi

  if [[ "$DO_PUSH" == "false" ]]; then
    log_info "Push not requested: Skipping push of ${image_tag}"
    return
  fi

  log_info "Pushing ${image_tag}..."

  if $CONTAINER_CMD push "${image_tag}"; then
    log_success "Pushed ${image_tag}"
  else
    log_error "Failed to push ${image_tag}"
    exit 1
  fi

  # Also push the 'latest' tag
  log_info "Pushing ${name}:latest..."
  if $CONTAINER_CMD push "${name}:latest"; then
    log_success "Pushed ${name}:latest"
  else
    log_error "Failed to push ${name}:latest"
    exit 1
  fi
}

# Main execution
main() {
  log_info "Moltbook Container Image Build"
  log_info "================================"
  log_info "Registry: ${REGISTRY}"
  log_info "Tag: ${TAG}"
  log_info "Dry run: ${DRY_RUN}"
  log_info "Push: ${DO_PUSH}"

  # Warning about environment
  if [[ -f /.dockerenv ]] || grep -qa docker /proc/1/cgroup 2>/dev/null; then
    log_warning "=========================================="
    log_warning "WARNING: Possible containerized environment"
    log_warning "=========================================="
    log_warning "Docker builds may fail due to overlay filesystem limitations."
    log_warning "If build fails, use GitHub Actions or build from a non-containerized environment."
    log_warning "See .github/workflows/build-images.yml for automated builds."
  fi
  echo ""

  check_prerequisites
  authenticate
  echo ""

  # Build API
  if [[ "$BUILD_API" == "true" ]]; then
    build_image "${API_IMAGE_NAME}" "${PROJECT_ROOT}/api/Dockerfile" "${PROJECT_ROOT}/api"
    push_image "${API_IMAGE_NAME}"
    echo ""
  fi

  # Build Frontend
  if [[ "$BUILD_FRONTEND" == "true" ]]; then
    build_image "${FRONTEND_IMAGE_NAME}" "${PROJECT_ROOT}/moltbook-frontend/Dockerfile" "${PROJECT_ROOT}/moltbook-frontend"
    push_image "${FRONTEND_IMAGE_NAME}"
    echo ""
  fi

  log_success "Build process completed successfully!"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "To push these images, run:"
    log_info "  GITHUB_TOKEN=your_token $0 --push --tag ${TAG}"
  fi

  if [[ "$DO_PUSH" == "true" ]]; then
    log_info "Images pushed to ${REGISTRY}:"
    if [[ "$BUILD_API" == "true" ]]; then
      log_info "  - ${API_IMAGE_NAME}:${TAG}"
    fi
    if [[ "$BUILD_FRONTEND" == "true" ]]; then
      log_info "  - ${FRONTEND_IMAGE_NAME}:${TAG}"
    fi
  fi
}

main "$@"
