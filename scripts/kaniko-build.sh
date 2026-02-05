#!/bin/bash
# Kaniko Build Helper Script
#
# This script simplifies triggering Kaniko builds from within the devpod environment.
# It provides a convenient wrapper around kubectl exec commands to the kaniko-build-runner.
#
# Usage:
#   ./scripts/kaniko-build.sh [OPTIONS]
#
# Options:
#   --all           Build both API and Frontend (default)
#   --api-only      Build only the API image
#   --frontend-only Build only the Frontend image
#   --tag TAG       Use specific image tag (default: latest)
#   --deploy        Deploy the kaniko-build-runner if not present
#   --watch         Watch the build logs
#   --help          Show this help message
#
# Examples:
#   ./scripts/kaniko-build.sh --all                    # Build both images
#   ./scripts/kaniko-build.sh --api-only --tag v1.0.0  # Build API with tag
#   ./scripts/kaniko-build.sh --deploy --all           # Deploy and build
#
# Prerequisites:
#   - kubectl configured for the cluster
#   - kaniko-build-runner deployment (use --deploy to create it)
#   - ghcr-credentials secret in moltbook namespace

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
NAMESPACE="${MOLTBOOK_NAMESPACE:-moltbook}"
DEPLOYMENT_NAME="kaniko-build-runner"
DEFAULT_TAG="${IMAGE_TAG:-latest}"

# Parse arguments
BUILD_ALL=true
BUILD_API=false
BUILD_FRONTEND=false
DO_DEPLOY=false
DO_WATCH=false
TAG="$DEFAULT_TAG"

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      BUILD_ALL=true
      BUILD_API=false
      BUILD_FRONTEND=false
      shift
      ;;
    --api-only)
      BUILD_ALL=false
      BUILD_API=true
      BUILD_FRONTEND=false
      shift
      ;;
    --frontend-only)
      BUILD_ALL=false
      BUILD_API=false
      BUILD_FRONTEND=true
      shift
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --deploy)
      DO_DEPLOY=true
      shift
      ;;
    --watch)
      DO_WATCH=true
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

# Check if kubectl is available
check_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl or use an environment with kubectl available."
    exit 1
  fi
  log_success "kubectl found"
}

# Check if kaniko-build-runner deployment exists
check_deployment() {
  log_info "Checking for kaniko-build-runner deployment..."

  if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
    log_success "kaniko-build-runner deployment found"
    return 0
  else
    log_warning "kaniko-build-runner deployment not found"
    return 1
  fi
}

# Deploy kaniko-build-runner
deploy_kaniko() {
  log_info "Deploying kaniko-build-runner..."

  local kaniko_dir="${PROJECT_ROOT}/k8s/kaniko"

  if [[ ! -d "$kaniko_dir" ]]; then
    log_error "Kaniko directory not found at $kaniko_dir"
    exit 1
  fi

  # Apply all kaniko manifests
  kubectl apply -f "$kaniko_dir/"

  # Wait for deployment to be ready
  log_info "Waiting for deployment to be ready..."
  kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=60s

  log_success "kaniko-build-runner deployed successfully"
}

# Trigger a build
trigger_build() {
  local script_path="$1"

  log_info "Triggering build: $script_path"
  log_info "Image tag: $TAG"
  echo ""

  local exec_cmd=(
    kubectl exec
    -it deployment/"$DEPLOYMENT_NAME"
    -n "$NAMESPACE"
    --
  )

  if [[ "$DO_WATCH" == "true" ]]; then
    # Run with logs following
    "${exec_cmd[@]}" sh -c "IMAGE_TAG=$TAG $script_path"
  else
    # Run in background and show pod status
    "${exec_cmd[@]}" sh -c "IMAGE_TAG=$TAG $script_path" &

    local build_pid=$!
    log_info "Build started in background (PID: $build_pid)"
    log_info "Check build status with: kubectl logs -f deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
  fi
}

# Main execution
main() {
  log_info "Kaniko Build Helper"
  log_info "==================="
  log_info "Namespace: ${NAMESPACE}"
  log_info "Tag: ${TAG}"
  echo ""

  check_kubectl

  # Deploy if requested
  if [[ "$DO_DEPLOY" == "true" ]]; then
    deploy_kaniko
    echo ""
  fi

  # Check deployment exists
  if ! check_deployment; then
    log_error "kaniko-build-runner deployment not found"
    log_error "Run with --deploy to deploy it, or deploy manually:"
    log_error "  kubectl apply -f k8s/kaniko/"
    exit 1
  fi

  # Determine which build script to run
  local build_script=""
  if [[ "$BUILD_ALL" == "true" ]]; then
    build_script="/scripts/build-all.sh"
  elif [[ "$BUILD_API" == "true" ]]; then
    build_script="/scripts/build-api.sh"
  elif [[ "$BUILD_FRONTEND" == "true" ]]; then
    build_script="/scripts/build-frontend.sh"
  fi

  # Trigger build
  trigger_build "$build_script"

  log_success "Build triggered successfully!"
  echo ""

  # Show how to view logs
  if [[ "$DO_WATCH" != "true" ]]; then
    log_info "View build logs:"
    log_info "  kubectl logs -f deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
    echo ""
    log_info "View pod status:"
    log_info "  kubectl get pods -n $NAMESPACE -l app=kaniko-build-runner"
  fi
}

main "$@"
