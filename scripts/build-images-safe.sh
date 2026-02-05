#!/bin/bash
# Moltbook Safe Container Image Build Wrapper
# Automatically detects environment and routes to appropriate build method
#
# Usage:
#   ./scripts/build-images-safe.sh [OPTIONS]
#
# Options:
#   --dry-run       Build images without pushing to registry
#   --push          Push images to registry (requires GITHUB_TOKEN)
#   --api-only      Build only the API image
#   --frontend-only Build only the Frontend image
#   --tag TAG       Use specific tag instead of 'latest'
#   --force-local   Force local build even in devpod (may fail)
#   --gh-actions    Use GitHub Actions even on local machine
#   --watch         Watch GitHub Actions workflow run (with --gh-actions)
#   --help          Show this help message
#
# Examples:
#   ./scripts/build-images-safe.sh --dry-run                    # Build only, don't push
#   ./scripts/build-images-safe.sh --push                       # Build and push
#   ./scripts/build-images-safe.sh --push --tag v1.0.0          # Build with specific tag
#
# Environment Detection:
#   - In devpod/Kubernetes: Uses GitHub Actions automatically
#   - On local machine: Uses Docker/Podman locally
#   - Override with --force-local or --gh-actions

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_devpod() {
  echo -e "${CYAN}[DEVPOD]${NC} $*"
}

# Detect if running in devpod/Kubernetes environment
is_devpod_environment() {
  # Check for Kubernetes service account token
  if [[ -f "/var/run/secrets/kubernetes.io/serviceaccount/token" ]]; then
    return 0
  fi

  # Check for devpod environment variables
  if [[ -n "${DEVPOD:-}" ]] || [[ -n "${DEVPOD_NAME:-}" ]]; then
    return 0
  fi

  # Check for container markers
  if [[ -f "/.dockerenv" ]] || [[ -f "/run/.containerenv" ]]; then
    return 0
  fi

  # Check cgroup for Kubernetes container
  if [[ -f "/proc/1/cgroup" ]]; then
    if grep -q "kubepods\|kubepod" /proc/1/cgroup 2>/dev/null; then
      return 0
    fi
  fi

  # Check hostname for devpod patterns
  local hostname
  hostname=$(hostname 2>/dev/null || echo "")
  if [[ "$hostname" =~ ^devpod- ]] || [[ "$hostname" =~ .*-workspace-.* ]]; then
    return 0
  fi

  return 1
}

# Show devpod build instructions
show_devpod_instructions() {
  log_devpod "=========================================="
  log_devpod "DETECTED DEVPod/KUBERNETES ENVIRONMENT"
  log_devpod "=========================================="
  echo ""
  log_warning "Docker builds are NOT supported in devpod environments!"
  echo ""
  log_info "Why?"
  echo "  Devpods run inside Kubernetes with overlayfs storage."
  echo "  Docker-in-Docker creates nested overlay filesystems."
  echo "  Linux kernel does NOT support nested overlayfs mounts."
  echo ""
  log_info "Solution Options:"
  echo ""
  echo "  1. Use GitHub Actions (Recommended):"
  echo "     $0 --gh-actions --push"
  echo ""
  echo "  2. Build on host machine:"
  echo "     SSH to your host, cd to project, run docker build"
  echo ""
  echo "  3. Use pre-built images from registry:"
  echo "     kubectl set image deployment/moltbook-frontend ..."
  echo ""
  log_info "To use GitHub Actions for building:"
  echo "  $0 --gh-actions --push"
  echo ""
  log_info "To force local build (will likely fail):"
  echo "  $0 --force-local [options]"
  echo ""
}

# Check for GitHub CLI
check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found. Please install it first."
    log_error "Visit: https://cli.github.com/"
    return 1
  fi

  if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub CLI."
    log_error "Run: gh auth login"
    return 1
  fi

  return 0
}

# Trigger GitHub Actions build
run_github_actions_build() {
  local watch=false

  # Parse watch flag from remaining arguments
  for arg in "$@"; do
    if [[ "$arg" == "--watch" ]]; then
      watch=true
    fi
  done

  log_info "Using GitHub Actions for image build..."
  echo ""

  if ! check_gh_cli; then
    log_error "Cannot use GitHub Actions. Please install and authenticate gh CLI."
    return 1
  fi

  # Trigger the devpod build script
  if [[ "$watch" == "true" ]]; then
    "${SCRIPT_DIR}/build-images-devpod.sh" --watch
  else
    "${SCRIPT_DIR}/build-images-devpod.sh"
  fi
}

# Run local build
run_local_build() {
  log_info "Using local Docker/Podman for image build..."
  echo ""

  "${SCRIPT_DIR}/build-images.sh" "$@"
}

# Parse arguments
WATCH=false
FORCE_LOCAL=false
USE_GH_ACTIONS=false
AUTO_DETECT=true
OTHER_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --watch)
      WATCH=true
      OTHER_ARGS+=("$1")
      shift
      ;;
    --force-local)
      FORCE_LOCAL=true
      AUTO_DETECT=false
      shift
      ;;
    --gh-actions)
      USE_GH_ACTIONS=true
      AUTO_DETECT=false
      OTHER_ARGS+=("$1")
      shift
      ;;
    --help)
      sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
      exit 0
      ;;
    *)
      OTHER_ARGS+=("$1")
      shift
      ;;
  esac
done

# Main execution
main() {
  log_info "Moltbook Safe Container Image Build"
  log_info "==================================="
  echo ""

  # Determine which build method to use
  if [[ "$AUTO_DETECT" == "true" ]]; then
    if is_devpod_environment; then
      show_devpod_instructions

      # Auto-switch to GitHub Actions
      log_info "Automatically switching to GitHub Actions build..."
      echo ""

      if [[ "$WATCH" == "true" ]]; then
        run_github_actions_build --watch
      else
        run_github_actions_build
      fi
    else
      # Local machine - use local Docker/Podman
      run_local_build "${OTHER_ARGS[@]}"
    fi
  elif [[ "$FORCE_LOCAL" == "true" ]]; then
    if is_devpod_environment; then
      log_warning "Forcing local build in devpod environment..."
      log_warning "This will likely fail due to overlay filesystem issues."
      echo ""
      log_info "Press Ctrl+C to cancel, or wait 5 seconds to proceed..."
      sleep 5
      echo ""
    fi
    run_local_build "${OTHER_ARGS[@]}"
  elif [[ "$USE_GH_ACTIONS" == "true" ]]; then
    if [[ "$WATCH" == "true" ]]; then
      run_github_actions_build --watch
    else
      run_github_actions_build
    fi
  fi
}

main "${OTHER_ARGS[@]}"
