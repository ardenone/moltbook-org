#!/bin/bash
# ============================================================================
# MOLTBOOK NAMESPACE SETUP SCRIPT
# ============================================================================
#
# This script sets up the moltbook namespace and grants the devpod
# ServiceAccount the necessary permissions to manage it.
#
# PREREQUISITE: Run as a cluster administrator (with cluster-admin privileges)
#
# USAGE:
#   ./setup-namespace.sh
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/NAMESPACE_SETUP_REQUEST.yml"

echo "========================================================================"
echo "MOLTBOOK NAMESPACE SETUP"
echo "========================================================================"
echo ""
echo "This script will:"
echo "  1. Grant namespace creation permissions to devpod ServiceAccount"
echo "  2. Create the 'moltbook' namespace"
echo ""
echo "Prerequisites: cluster-admin privileges"
echo ""

# Check if running as cluster-admin
echo "Checking permissions..."
if kubectl auth can-i create clusterrole 2>/dev/null; then
    echo "✓ Cluster-admin permissions confirmed"
else
    echo "✗ ERROR: This script requires cluster-admin privileges"
    echo "  Current user lacks permission to create ClusterRole"
    exit 1
fi

# Check if namespace already exists
echo ""
echo "Checking for existing moltbook namespace..."
if kubectl get namespace moltbook >/dev/null 2>&1; then
    echo "⚠ WARNING: Namespace 'moltbook' already exists"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 0
    fi
fi

# Apply the manifest
echo ""
echo "Applying namespace setup manifest..."
kubectl apply -f "$MANIFEST"

# Verify
echo ""
echo "Verifying setup..."
if kubectl get namespace moltbook >/dev/null 2>&1; then
    echo "✓ Namespace 'moltbook' created successfully"
else
    echo "✗ ERROR: Failed to create namespace"
    exit 1
fi

if kubectl get clusterrole namespace-creator >/dev/null 2>&1; then
    echo "✓ ClusterRole 'namespace-creator' created"
else
    echo "✗ ERROR: Failed to create ClusterRole"
    exit 1
fi

if kubectl get clusterrolebinding devpod-namespace-creator >/dev/null 2>&1; then
    echo "✓ ClusterRoleBinding 'devpod-namespace-creator' created"
else
    echo "✗ ERROR: Failed to create ClusterRoleBinding"
    exit 1
fi

echo ""
echo "========================================================================"
echo "SETUP COMPLETE!"
echo "========================================================================"
echo ""
echo "Next steps:"
echo "  1. The devpod ServiceAccount can now deploy the moltbook platform"
echo "  2. From the devpod, run:"
echo ""
echo "     kubectl apply -k /home/coder/Research/moltbook-org/k8s/"
echo ""
echo "  3. Or use the no-namespace kustomization:"
echo ""
echo "     kubectl apply -k /home/coder/Research/moltbook-org/k8s/kustomization-no-namespace.yml"
echo ""
