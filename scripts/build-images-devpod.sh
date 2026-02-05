#!/bin/bash
# Moltbook Container Image Build Helper for Devpod
# Triggers GitHub Actions workflow to build and push images
#
# Usage:
#   ./scripts/build-images-devpod.sh [OPTIONS]
#
# Options:
#   --watch         Watch the workflow run in real-time
#   --api-only      Build only the API image (not yet supported)
#   --frontend-only Build only the Frontend image (not yet supported)
#   --help          Show this help message
#
# Examples:
#   ./scripts/build-images-devpod.sh                # Trigger build and exit
#   ./scripts/build-images-devpod.sh --watch        # Trigger and watch progress
#
# Why This Script?
# Devpods cannot build Docker images due to overlay filesystem limitations.
# This script triggers GitHub Actions to build images externally.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKFLOW_FILE=".github/workflows/build-images.yml"

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

  # Check for GitHub CLI (gh)
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found. Please install it first."
    log_error "Visit: https://cli.github.com/"
    exit 1
  fi

  # Check authentication
  if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub CLI."
    log_error "Run: gh auth login"
    exit 1
  fi

  # Verify repo is a git repo
  if ! git rev-parse --git-dir &> /dev/null; then
    log_error "Not a git repository. Cannot trigger workflow."
    exit 1
  fi

  # Check if workflow file exists
  if [[ ! -f "${PROJECT_ROOT}/${WORKFLOW_FILE}" ]]; then
    log_error "Workflow file not found: ${WORKFLOW_FILE}"
    exit 1
  fi

  log_success "Prerequisites check passed"
}

# Trigger GitHub Actions workflow
trigger_workflow() {
  log_info "Triggering GitHub Actions workflow..."

  cd "$PROJECT_ROOT"

  # Trigger the workflow
  RUN_ID=$(gh workflow run "${WORKFLOW_FILE}" --json databaseId --jq '.databaseId' 2>&1)

  if [[ $? -ne 0 ]]; then
    log_error "Failed to trigger workflow"
    log_error "$RUN_ID"
    exit 1
  fi

  log_success "Workflow triggered successfully!"
  echo ""

  # Get run URL
  log_info "Run ID: ${RUN_ID}"

  # Try to get the run URL
  RUN_URL=$(gh run view "$RUN_ID" --json url --jq '.url' 2>/dev/null || echo "")

  if [[ -n "$RUN_URL" ]]; then
    log_info "Run URL: ${RUN_URL}"
    echo ""
    log_info "You can monitor the build at:"
    echo "  ${RUN_URL}"
  fi

  echo ""
}

# Watch workflow run
watch_workflow() {
  log_info "Waiting for workflow run to start..."

  # List recent runs to find our triggered run
  sleep 2

  log_info "Watching workflow run (Ctrl+C to stop watching)..."
  echo ""

  # Watch the latest run
  gh run watch --exit-status || {
    log_warning "Run monitoring stopped or failed"
    log_info "You can check the status manually with: gh run list"
    return 1
  }

  log_success "Workflow completed!"
  echo ""

  # Show run summary
  log_info "Run Summary:"
  gh run view --json conclusion,updatedAt,displayTitle,workflowName
}

# Main execution
main() {
  WATCH=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --watch)
        WATCH=true
        shift
        ;;
      --help)
        sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done

  log_info "Moltbook Container Image Build (Devpod Mode)"
  log_info "=============================================="
  echo ""

  check_prerequisites
  trigger_workflow

  if [[ "$WATCH" == "true" ]]; then
    watch_workflow
  else
    log_info "Use 'gh run list' to check the status"
    log_info "Use 'gh run watch' to watch the latest run"
  fi

  echo ""
  log_success "Done!"
}

main "$@"
