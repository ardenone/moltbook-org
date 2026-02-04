#!/bin/bash
# ArgoCD Installation Script for ardenone-cluster
#
# This script installs ArgoCD GitOps operator in ardenone-cluster.
# Requires cluster-admin privileges to run.
#
# Usage: ./k8s/install-argocd.sh [--verify] [--uninstall]
#
# Options:
#   --verify   Verify ArgoCD installation status
#   --uninstall Remove ArgoCD from the cluster
#   (no args)  Install ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="stable"
INSTALL_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check cluster admin access
check_cluster_admin() {
    print_info "Checking for cluster-admin privileges..."

    if ! kubectl auth can-i create customresourcedefinitions 2>/dev/null; then
        print_error "This script requires cluster-admin privileges."
        print_error "Current user cannot create CustomResourceDefinitions."
        echo ""
        print_info "To fix this, you need to:"
        print_info "  1. Have a kubeconfig with cluster-admin access, OR"
        print_info "  2. Create a ClusterRoleBinding for your ServiceAccount:"
        echo ""
        echo "      kubectl create clusterrolebinding argocd-installer \\
                --clusterrole=cluster-admin \\
                --serviceaccount=devpod:default"
        echo ""
        print_info "Then run this script again."
        exit 1
    fi

    print_info "Cluster-admin privileges confirmed."
}

# Function to install ArgoCD
install_argocd() {
    print_info "Starting ArgoCD installation..."

    # Check if ArgoCD is already installed
    if kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
        print_warn "ArgoCD namespace '${ARGOCD_NAMESPACE}' already exists."
        read -p "Do you want to reinstall ArgoCD? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation aborted."
            exit 0
        fi
        print_warn "Removing existing ArgoCD installation..."
        uninstall_argocd
    fi

    # Download and apply the official ArgoCD manifest
    print_info "Downloading ArgoCD manifest from official repository..."
    print_info "Version: ${ARGOCD_VERSION}"
    print_info "URL: ${INSTALL_MANIFEST_URL}"

    if kubectl apply -f "${INSTALL_MANIFEST_URL}"; then
        print_info "ArgoCD manifest applied successfully."
    else
        print_error "Failed to apply ArgoCD manifest."
        exit 1
    fi

    # Wait for ArgoCD pods to be ready
    print_info "Waiting for ArgoCD pods to be ready..."
    kubectl wait \
        --for=condition=ready pod \
        -l app.kubernetes.io/name=argocd-server \
        -n "${ARGOCD_NAMESPACE}" \
        --timeout=300s

    print_info "ArgoCD installation completed successfully!"
    echo ""
    print_info "Next steps:"
    print_info "  1. Verify installation: ./k8s/install-argocd.sh --verify"
    print_info "  2. Apply Moltbook Application: kubectl apply -f k8s/argocd-application.yml"
    print_info "  3. Access ArgoCD UI:"
    echo "        kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "        Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Function to uninstall ArgoCD
uninstall_argocd() {
    print_warn "Uninstalling ArgoCD..."

    # Delete the namespace (which deletes all resources)
    if kubectl delete namespace "${ARGOCD_NAMESPACE}" --ignore-not-found=true --timeout=60s; then
        print_info "ArgoCD namespace deleted."
    else
        print_warn "Namespace deletion timed out or failed. Force deleting..."
        kubectl delete namespace "${ARGOCD_NAMESPACE}" --force --grace-period=0 2>/dev/null || true
    fi

    # Delete CRDs (this removes all ArgoCD custom resources)
    print_info "Removing ArgoCD CRDs..."
    kubectl delete crd \
        applications.argoproj.io \
        appprojects.argoproj.io \
        applicationsets.argoproj.io \
        argocdextensions.argoproj.io \
        argocdexports.argoproj.io \
        argocdnotifications.argoproj.io \
        argocdconfigs.argoproj.io \
        --ignore-not-found=true

    print_info "ArgoCD uninstalled."
}

# Function to verify ArgoCD installation
verify_argocd() {
    print_info "Verifying ArgoCD installation..."

    # Check namespace
    if kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
        print_info "Namespace '${ARGOCD_NAMESPACE}' exists."
    else
        print_error "Namespace '${ARGOCD_NAMESPACE}' not found. ArgoCD is not installed."
        exit 1
    fi

    # Check CRDs
    print_info "Checking ArgoCD CRDs..."
    CRDS=(
        "applications.argoproj.io"
        "appprojects.argoproj.io"
        "applicationsets.argoproj.io"
    )

    for crd in "${CRDS[@]}"; do
        if kubectl get crd "${crd}" >/dev/null 2>&1; then
            print_info "  ✓ ${crd}"
        else
            print_error "  ✗ ${crd} not found"
        fi
    done

    # Check pods
    print_info "Checking ArgoCD pods..."
    if kubectl get pods -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
        kubectl get pods -n "${ARGOCD_NAMESPACE}" -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,STATUS:.status.phase | grep -v NAME
    else
        print_error "No pods found in '${ARGOCD_NAMESPACE}' namespace."
    fi

    # Check for Moltbook Application
    print_info "Checking for Moltbook Application..."
    if kubectl get application moltbook -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
        print_info "Moltbook Application found."
        kubectl get application moltbook -n "${ARGOCD_NAMESPACE}" -o custom-columns=NAME:.metadata.name,SYNC_STATUS:.status.sync.status,HEALTH:.status.health.status
    else
        print_warn "Moltbook Application not found. Apply with:"
        echo "    kubectl apply -f k8s/argocd-application.yml"
    fi
}

# Main script logic
case "${1:-install}" in
    --verify|verify)
        verify_argocd
        ;;
    --uninstall|uninstall)
        check_cluster_admin
        uninstall_argocd
        ;;
    --help|help)
        echo "ArgoCD Installation Script for ardenone-cluster"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (no args)  Install ArgoCD (default)"
        echo "  --verify   Verify ArgoCD installation status"
        echo "  --uninstall Remove ArgoCD from the cluster"
        echo "  --help     Show this help message"
        echo ""
        exit 0
        ;;
    *)
        check_cluster_admin
        install_argocd
        ;;
esac
