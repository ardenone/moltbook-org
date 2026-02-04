#!/bin/bash
# Moltbook Safe Build Wrapper
# Detects devpod environment and prevents Docker builds in incompatible environments
#
# This script prevents the nested overlayfs error that occurs when building
# Docker images inside devpod/Kubernetes containerized environments.

set -euo pipefail

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

# Check if running in devpod environment
check_devpod_environment() {
  log_info "Checking build environment..."

  # Indicators that we're in a devpod/Kubernetes containerized environment
  local IN_DEVPOD=false

  # Check for Kubernetes service account token
  if [[ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]]; then
    IN_DEVPOD=true
  fi

  # Check for devpod-specific environment variables
  if [[ -n "${DEVPOD:-}" ]] || [[ -n "${DEVPOD_NAME:-}" ]]; then
    IN_DEVPOD=true
  fi

  # Check if we're running in a container (likely devpod)
  if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
    IN_DEVPOD=true
  fi

  # Check hostname pattern (devpods typically have generated names)
  local hostname=$(hostname 2>/dev/null || echo "")
  if [[ "$hostname" =~ ^devpod- ]] || [[ "$hostname" =~ -workspace-$ ]]; then
    IN_DEVPOD=true
  fi

  if [[ "$IN_DEVPOD" == "true" ]]; then
    log_warning "Detected devpod/containerized environment"
    echo ""
    log_error "╔════════════════════════════════════════════════════════════════════════╗"
    log_error "║        Docker builds DO NOT WORK in devpod environments              ║"
    log_error "╠════════════════════════════════════════════════════════════════════════╣"
    log_error "║  PROBLEM:                                                            ║"
    log_error "║    Nested overlayfs is not supported by the Linux kernel             ║"
    log_error "║                                                                      ║"
    log_error "║  ERROR YOU'LL SEE:                                                   ║"
    log_error "║    'mount source: overlay... err: invalid argument'                  ║"
    log_error "╠════════════════════════════════════════════════════════════════════════╣"
    log_error "║  RECOMMENDED SOLUTIONS:                                              ║"
    log_error "║                                                                      ║"
    log_error "║  1. Use GitHub Actions (PRIMARY METHOD):                             ║"
    log_error "║     gh workflow run build-push.yml                                   ║"
    log_error "║     gh run watch                                                     ║"
    log_error "║                                                                      ║"
    log_error "║  2. Build on your host machine:                                      ║"
    log_error "║     Exit devpod, then run:                                           ║"
    log_error "║     ./scripts/build-images.sh [options]                              ║"
    log_error "║                                                                      ║"
    log_error "║  3. Use pre-built images from ghcr.io:                               ║"
    log_error "║     ghcr.io/ardenone/moltbook-api:latest                             ║"
    log_error "║     ghcr.io/ardenone/moltbook-frontend:latest                        ║"
    log_error "╠════════════════════════════════════════════════════════════════════════╣"
    log_error "║  FOR MORE DETAILS:                                                    ║"
    log_error "║     See DOCKER_BUILD_WORKAROUND.md and BUILD_IMAGES.md                ║"
    log_error "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    return 1
  else
    log_success "Running on host machine (not in devpod) - safe to build"
    return 0
  fi
}

# Main execution
main() {
  echo ""
  log_info "Moltbook Safe Build Wrapper"
  log_info "============================"
  echo ""

  if check_devpod_environment; then
    echo ""
    log_info "Delegating to build-images.sh..."
    echo ""
    # Pass all arguments to the actual build script
    exec "$(dirname "${BASH_SOURCE[0]}")/build-images.sh" "$@"
  else
    echo ""
    log_info "To build images, use one of the recommended solutions above."
    exit 1
  fi
}

main "$@"
