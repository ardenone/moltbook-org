#!/usr/bin/env bash

# Moltbook Deployment Script for ardenone-cluster
# This script must be executed by a cluster administrator with cluster-admin permissions
#
# Usage:
#   ./scripts/deploy-moltbook.sh [--skip-rbac] [--skip-secrets] [--dry-run]
#
# Options:
#   --skip-rbac     Skip RBAC setup (if already configured)
#   --skip-secrets  Skip SealedSecrets application (if already applied)
#   --dry-run       Validate manifests without applying them
#
# Prerequisites:
#   - kubectl with cluster-admin access
#   - CNPG (CloudNativePG) operator installed
#   - SealedSecrets controller installed
#   - Traefik ingress controller installed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/k8s"

# Options
SKIP_RBAC=false
SKIP_SECRETS=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-rbac)
      SKIP_RBAC=true
      shift
      ;;
    --skip-secrets)
      SKIP_SECRETS=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--skip-rbac] [--skip-secrets] [--dry-run]"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Moltbook Deployment Script${NC}"
echo -e "${BLUE}Target: ardenone-cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to print step
print_step() {
  echo -e "${GREEN}[Step $1]${NC} $2"
}

# Function to print error
print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print warning
print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check command exists
check_command() {
  if ! command -v "$1" &> /dev/null; then
    print_error "$1 is not installed or not in PATH"
    exit 1
  fi
}

# Verify prerequisites
print_step "0" "Verifying prerequisites..."
check_command kubectl
check_command kustomize

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
  print_error "Cannot connect to Kubernetes cluster"
  exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
echo -e "  Connected to cluster: ${BLUE}${CLUSTER_NAME}${NC}"

# Check if dry-run mode
if [ "$DRY_RUN" = true ]; then
  print_warning "Running in DRY-RUN mode - no changes will be applied"
  APPLY_CMD="kubectl apply --dry-run=client"
else
  APPLY_CMD="kubectl apply"
fi

# Step 1: Apply ClusterRoleBinding for namespace creation
if [ "$SKIP_RBAC" = false ]; then
  print_step "1" "Applying ClusterRoleBinding for namespace creation..."

  if ! $APPLY_CMD -f "$K8S_DIR/namespace/devpod-namespace-creator-rbac.yml"; then
    print_error "Failed to apply ClusterRoleBinding. You need cluster-admin permissions."
    exit 1
  fi

  echo -e "  ${GREEN}✓${NC} ClusterRoleBinding applied successfully"
else
  print_warning "Skipping RBAC setup (--skip-rbac specified)"
fi

# Step 2: Create namespace
print_step "2" "Creating moltbook namespace..."

if ! $APPLY_CMD -f "$K8S_DIR/namespace/moltbook-namespace.yml"; then
  print_error "Failed to create namespace"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} Namespace created successfully"

# Step 3: Apply namespace RBAC
print_step "3" "Applying namespace RBAC..."

if ! $APPLY_CMD -f "$K8S_DIR/namespace/moltbook-rbac.yml"; then
  print_error "Failed to apply namespace RBAC"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} Namespace RBAC applied successfully"

# Step 4: Apply SealedSecrets
if [ "$SKIP_SECRETS" = false ]; then
  print_step "4" "Applying SealedSecrets..."

  # Check if sealed-secrets controller is running
  if ! kubectl get namespace sealed-secrets &> /dev/null; then
    print_warning "sealed-secrets namespace not found. SealedSecrets controller may not be installed."
  fi

  for secret_file in \
    "$K8S_DIR/secrets/moltbook-postgres-superuser-sealedsecret.yml" \
    "$K8S_DIR/secrets/moltbook-db-credentials-sealedsecret.yml" \
    "$K8S_DIR/secrets/moltbook-api-sealedsecret.yml"; do

    if [ -f "$secret_file" ]; then
      echo "  Applying $(basename "$secret_file")..."
      if ! $APPLY_CMD -f "$secret_file"; then
        print_error "Failed to apply $(basename "$secret_file")"
        exit 1
      fi
    else
      print_warning "SealedSecret file not found: $secret_file"
    fi
  done

  echo -e "  ${GREEN}✓${NC} SealedSecrets applied successfully"

  # Wait for secrets to be decrypted
  if [ "$DRY_RUN" = false ]; then
    echo "  Waiting for SealedSecrets to be decrypted..."
    sleep 5

    # Verify secrets were created
    SECRET_COUNT=$(kubectl get secrets -n moltbook --no-headers 2>/dev/null | wc -l)
    echo "  Found $SECRET_COUNT secrets in moltbook namespace"
  fi
else
  print_warning "Skipping SealedSecrets (--skip-secrets specified)"
fi

# Step 5: Deploy all resources with Kustomize
print_step "5" "Deploying all resources with Kustomize..."

cd "$PROJECT_ROOT"

if ! $APPLY_CMD -k "$K8S_DIR/"; then
  print_error "Failed to apply Kustomize resources"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} All resources deployed successfully"

# Step 6: Verify deployment (skip in dry-run mode)
if [ "$DRY_RUN" = false ]; then
  print_step "6" "Verifying deployment..."

  echo "  Waiting for resources to be created..."
  sleep 5

  echo
  echo "  Pods:"
  kubectl get pods -n moltbook

  echo
  echo "  Services:"
  kubectl get svc -n moltbook

  echo
  echo "  IngressRoutes:"
  kubectl get ingressroutes -n moltbook

  echo
  echo "  CNPG Cluster:"
  kubectl get cluster -n moltbook 2>/dev/null || echo "  (CNPG cluster resource will appear shortly)"

  echo
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Deployment Summary${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo
  echo "  Namespace:  moltbook"
  echo "  Frontend:   https://moltbook.ardenone.com"
  echo "  API:        https://api-moltbook.ardenone.com"
  echo "  API Health: https://api-moltbook.ardenone.com/health"
  echo
  echo -e "${YELLOW}Next Steps:${NC}"
  echo "  1. Wait for all pods to be Running:"
  echo "     kubectl get pods -n moltbook -w"
  echo
  echo "  2. Check database initialization:"
  echo "     kubectl logs -n moltbook deployment/moltbook-db-init"
  echo
  echo "  3. Test API endpoint:"
  echo "     curl https://api-moltbook.ardenone.com/health"
  echo
  echo "  4. Access frontend:"
  echo "     open https://moltbook.ardenone.com"
  echo
else
  echo
  echo -e "${GREEN}Dry-run completed successfully!${NC}"
  echo "Run without --dry-run to apply changes."
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment script completed${NC}"
echo -e "${GREEN}========================================${NC}"
