#!/bin/bash
# create-moltbook-namespace.sh
#
# This script creates the moltbook namespace in ardenone-cluster.
# Requires cluster-admin permissions to run.
#
# Usage:
#   ./scripts/create-moltbook-namespace.sh
#
# This script should be run by a cluster administrator or user with
# cluster-scoped namespace creation permissions.

set -e

NAMESPACE="moltbook"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Creating Moltbook Namespace in ardenone-cluster ==="
echo ""

# Check if namespace already exists
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "✓ Namespace '$NAMESPACE' already exists"
    exit 0
fi

# Create namespace using the manifest
echo "Creating namespace '$NAMESPACE'..."
kubectl apply -f "$PROJECT_DIR/k8s/NAMESPACE_REQUEST.yml"

# Verify namespace was created
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "✓ Namespace '$NAMESPACE' created successfully"
    echo ""
    echo "Next steps:"
    echo "1. Apply RBAC for namespace management (optional):"
    echo "   kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml"
    echo ""
    echo "2. Deploy Moltbook resources:"
    echo "   kubectl apply -k k8s/"
    echo ""
    echo "Or use ArgoCD if configured:"
    echo "   kubectl apply -f k8s/argocd-application.yml"
else
    echo "✗ Failed to create namespace '$NAMESPACE'"
    exit 1
fi
