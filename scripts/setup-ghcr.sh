#!/bin/bash
# Setup GitHub Container Registry for Moltbook Images
#
# This script helps set up the GitHub repository for automatic image builds via GitHub Actions.
#
# Usage:
#   ./scripts/setup-ghcr.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
log_info "==================================================================="
log_info "GitHub Container Registry Setup for Moltbook"
log_info "==================================================================="
echo ""

# Check if git is initialized
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  log_error "Not a git repository. Please initialize git first."
  exit 1
fi

# Check for existing remote
if git remote get-url origin > /dev/null 2>&1; then
  REMOTE_URL=$(git remote get-url origin)
  log_info "Existing git remote found: ${REMOTE_URL}"
else
  log_warning "No git remote 'origin' found."
  echo ""
  log_info "To enable GitHub Actions builds, you need to:"
  echo "  1. Create a new GitHub repository at https://github.com/new"
  echo "  2. Add it as a remote:"
  echo "     git remote add origin https://github.com/YOUR_USERNAME/moltbook-org.git"
  echo "  3. Push the code:"
  echo "     git push -u origin main"
  echo ""
fi

echo ""
log_info "STEP 1: GitHub Repository Setup"
echo "-----------------------------------"
echo ""
echo "If you haven't already, create a GitHub repository:"
echo "  1. Go to https://github.com/new"
echo "  2. Repository name: moltbook-org (or your preferred name)"
echo "  3. Set to Public (recommended for ghcr.io free tier)"
echo "  4. Do NOT initialize with README (we have code already)"
echo ""

echo ""
log_info "STEP 2: Configure GitHub Actions Permissions"
echo "------------------------------------------------"
echo ""
echo "After creating the repository, configure Actions permissions:"
echo "  1. Go to: https://github.com/YOUR_USERNAME/moltbook-org/settings/actions"
echo "  2. Under 'Workflow permissions', select:"
echo "     - 'Read and write permissions'"
echo "  3. Check 'Allow GitHub Actions to create and approve pull requests'"
echo "  4. Click Save"
echo ""

echo ""
log_info "STEP 3: Enable Container Registry"
echo "------------------------------------"
echo ""
echo "GitHub Container Registry (ghcr.io) is enabled by default for public repositories."
echo "For private repositories, ensure Packages are enabled in repository settings."
echo ""

echo ""
log_info "STEP 4: Push to GitHub"
echo "-------------------------"
echo ""
echo "Run the following commands to push your code:"
echo ""
if git remote get-url origin > /dev/null 2>&1; then
  echo "  git push -u origin main"
else
  echo "  # First, add the remote (replace with your repo URL):"
  echo "  git remote add origin https://github.com/YOUR_USERNAME/moltbook-org.git"
  echo ""
  echo "  # Then push:"
  echo "  git push -u origin main"
fi
echo ""

echo ""
log_info "STEP 5: Monitor GitHub Actions Build"
echo "---------------------------------------"
echo ""
echo "After pushing, GitHub Actions will automatically build and push the images:"
echo "  1. Go to: https://github.com/YOUR_USERNAME/moltbook-org/actions"
echo "  2. Watch the 'Build and Push Docker Images' workflow"
echo "  3. Images will be available at:"
echo "     - ghcr.io/YOUR_USERNAME/api:latest"
echo "     - ghcr.io/YOUR_USERNAME/frontend:latest"
echo ""

echo ""
log_info "STEP 6: Update Kubernetes Manifests (if needed)"
echo "---------------------------------------------------"
echo ""
echo "If you're not using the 'moltbook' GitHub organization, update the image references:"
echo ""
echo "  # In k8s/api/deployment.yml and k8s/frontend/deployment.yml"
echo "  image: ghcr.io/YOUR_USERNAME/api:latest"
echo "  image: ghcr.io/YOUR_USERNAME/frontend:latest"
echo ""
echo "  # In k8s/kustomization.yml"
echo "  images:"
echo "    - name: ghcr.io/YOUR_USERNAME/api"
echo "      newName: ghcr.io/YOUR_USERNAME/api"
echo "      newTag: latest"
echo ""

echo ""
log_info "==================================================================="
log_success "Setup Complete!"
echo ""
log_warning "IMPORTANT: If you're deploying to ardenone-cluster from this devpod:"
echo "  The images will be built by GitHub Actions after you push to GitHub."
echo "  No local container build is required or possible in this environment."
echo "==================================================================="
echo ""
