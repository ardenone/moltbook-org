#!/bin/bash
# ============================================================================
# ARGOCD INSTALLATION SCRIPT FOR ARDENONE-CLUSTER
# ============================================================================
#
# This script installs ArgoCD in ardenone-cluster and sets up the Moltbook
# platform deployment via GitOps.
#
# PREREQUISITES:
#   1. Cluster admin must have applied k8s/ARGOCD_INSTALL_REQUEST.yml
#   2. Run this script from the devpod (has granted RBAC permissions)
#
# USAGE:
#   ./k8s/install-argocd.sh
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
ARGOCD_APP_MANIFEST="$SCRIPT_DIR/argocd-application.yml"

echo "========================================================================"
echo "ARGOCD INSTALLATION FOR ARDENONE-CLUSTER"
echo "========================================================================"
echo ""
echo "This script will:"
echo "  1. Install ArgoCD in the 'argocd' namespace"
echo "  2. Wait for ArgoCD components to be ready"
echo "  3. Apply the Moltbook ArgoCD Application manifest"
echo ""
echo "Prerequisites:"
echo "  - Cluster admin has applied k8s/ARGOCD_INSTALL_REQUEST.yml"
echo "  - Devpod ServiceAccount has argocd-installer ClusterRole"
echo ""

# Check if we have the required permissions
echo "Checking permissions..."
if kubectl auth can-i create customresourcedefinitions 2>/dev/null; then
    echo "✓ ArgoCD installation permissions confirmed"
else
    echo "✗ ERROR: Insufficient permissions"
    echo ""
    echo "The devpod ServiceAccount does not have ArgoCD installation permissions."
    echo ""
    echo "ACTION REQUIRED: A cluster administrator must run:"
    echo ""
    echo "  kubectl apply -f k8s/ARGOCD_INSTALL_REQUEST.yml"
    echo ""
    echo "See k8s/ARGOCD_INSTALL_README.md for detailed instructions."
    exit 1
fi

# Check if ArgoCD namespace exists
echo ""
echo "Checking ArgoCD namespace..."
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "⚠ WARNING: Namespace 'argocd' does not exist"
    echo "  Creating namespace..."
    kubectl create namespace argocd
    echo "✓ Namespace 'argocd' created"
else
    echo "✓ Namespace 'argocd' exists"
fi

# Check if ArgoCD is already installed
echo ""
echo "Checking for existing ArgoCD installation..."
if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo "⚠ WARNING: ArgoCD appears to be already installed"
    echo "  argocd-server deployment found"
    read -p "Continue with reinstallation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

# Install ArgoCD
echo ""
echo "Installing ArgoCD..."
echo "  Fetching manifest from: $ARGOCD_MANIFEST_URL"
if kubectl apply -n argocd -f "$ARGOCD_MANIFEST_URL"; then
    echo "✓ ArgoCD manifest applied"
else
    echo "✗ ERROR: Failed to apply ArgoCD manifest"
    exit 1
fi

# Wait for ArgoCD components to be ready
echo ""
echo "Waiting for ArgoCD components to be ready..."
echo "  (This may take 2-3 minutes..."

# Wait for argocd-server deployment
echo ""
echo "  Waiting for argocd-server deployment..."
if kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd; then
    echo "✓ argocd-server is ready"
else
    echo "⚠ WARNING: argocd-server did not become ready within timeout"
    echo "  Check status with: kubectl get pods -n argocd"
fi

# Verify ArgoCD pods
echo ""
echo "Verifying ArgoCD pods..."
ARGOCD_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd -o jsonpath='{.items[*].metadata.name}')
if [ -n "$ARGOCD_PODS" ]; then
    echo "✓ ArgoCD pods found:"
    kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd
else
    echo "⚠ WARNING: No ArgoCD pods found"
fi

# Apply the Moltbook ArgoCD Application manifest
echo ""
echo "========================================================================"
echo "APPLYING MOLTBOOK APPLICATION"
echo "========================================================================"
echo ""
echo "Applying ArgoCD Application manifest for Moltbook..."
if [ -f "$ARGOCD_APP_MANIFEST" ]; then
    kubectl apply -f "$ARGOCD_APP_MANIFEST"
    echo "✓ ArgoCD Application 'moltbook' applied"
else
    echo "✗ ERROR: ArgoCD Application manifest not found: $ARGOCD_APP_MANIFEST"
    exit 1
fi

# Wait a bit for the application to be processed
echo ""
echo "Waiting for ArgoCD to process the Application..."
sleep 5

# Check application status
echo ""
echo "Checking Application status..."
kubectl get application -n argocd

# Final summary
echo ""
echo "========================================================================"
echo "INSTALLATION COMPLETE!"
echo "========================================================================"
echo ""
echo "ArgoCD has been installed in ardenone-cluster."
echo ""
echo "Next steps:"
echo "  1. Monitor the Moltbook application sync:"
echo ""
echo "     kubectl get application -n argocd -w"
echo ""
echo "  2. Check the ArgoCD UI (if IngressRoute is configured):"
echo ""
echo "     kubectl get ingressroute -n argocd"
echo ""
echo "  3. Port-forward to access ArgoCD UI locally:"
echo ""
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "     Then open: https://localhost:8080"
echo ""
echo "  4. Get the initial admin password:"
echo ""
echo "     kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "========================================================================"
