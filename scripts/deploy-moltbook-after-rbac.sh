#!/bin/bash
# ============================================================================
# Moltbook Deployment Script (Post-RBAC)
# ============================================================================
#
# This script deploys Moltbook to ardenone-cluster after the RBAC
# permissions have been applied by a cluster administrator.
#
# Prerequisites:
#   1. Cluster admin has applied devpod-namespace-creator-rbac.yml
#   2. Cluster admin has created the moltbook namespace
#   3. Running from devpod with ServiceAccount: system:serviceaccount:devpod:default
#
# Usage:
#   ./scripts/deploy-moltbook-after-rbac.sh
#
# ============================================================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOLTBOOK_K8S_DIR="${REPO_ROOT}/k8s"
CLUSTER_CONFIG_DIR="${REPO_ROOT}/cluster-configuration/ardenone-cluster/moltbook"

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running in Kubernetes
    if [[ ! -f /var/run/secrets/kubernetes.io/serviceaccount/token ]]; then
        log_error "Not running in a Kubernetes pod"
        exit 1
    fi

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found in PATH"
        exit 1
    fi

    # Check current identity
    IDENTITY=$(kubectl auth whoami 2>/dev/null || echo "")
    if [[ ! "$IDENTITY" =~ "devpod" ]]; then
        log_warn "Current identity: $IDENTITY"
        log_warn "Expected: system:serviceaccount:devpod:default"
    else
        log_info "Authenticated as: $IDENTITY"
    fi

    # Check if RBAC is applied
    log_info "Checking if RBAC permissions are in place..."

    if kubectl get clusterrole namespace-creator &> /dev/null; then
        log_info "✅ ClusterRole 'namespace-creator' exists"
    else
        log_error "❌ ClusterRole 'namespace-creator' NOT found"
        log_error "Please ask a cluster-admin to apply:"
        log_error "  kubectl apply -f ${CLUSTER_CONFIG_DIR}/namespace/devpod-namespace-creator-rbac.yml"
        exit 1
    fi

    if kubectl get clusterrolebinding devpod-namespace-creator &> /dev/null; then
        log_info "✅ ClusterRoleBinding 'devpod-namespace-creator' exists"
    else
        log_error "❌ ClusterRoleBinding 'devpod-namespace-creator' NOT found"
        log_error "Please ask a cluster-admin to apply:"
        log_error "  kubectl apply -f ${CLUSTER_CONFIG_DIR}/namespace/devpod-namespace-creator-rbac.yml"
        exit 1
    fi

    # Check if namespace exists
    if kubectl get namespace moltbook &> /dev/null; then
        log_info "✅ Namespace 'moltbook' exists"
    else
        log_warn "⚠️  Namespace 'moltbook' NOT found"
        log_info "Creating namespace..."
        kubectl create namespace moltbook
        log_info "✅ Namespace 'moltbook' created"
    fi

    # Verify permissions
    log_info "Verifying devpod SA can create namespaces..."
    if kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default &> /dev/null; then
        log_info "✅ Devpod SA has namespace creation permissions"
    else
        log_error "❌ Devpod SA lacks namespace creation permissions"
        log_error "Please ask a cluster-admin to verify RBAC setup"
        exit 1
    fi

    log_info "All prerequisites met!"
}

verify_manifests() {
    log_info "Verifying Kubernetes manifests..."

    if [[ ! -d "${MOLTBOOK_K8S_DIR}" ]]; then
        log_error "K8s manifests directory not found: ${MOLTBOOK_K8S_DIR}"
        exit 1
    fi

    # Validate manifests with kubectl --dry-run
    log_info "Validating manifests (dry-run)..."

    # Find all YAML files and validate them
    find "${MOLTBOOK_K8S_DIR}" -name "*.yml" -o -name "*.yaml" | while read -r manifest; do
        log_info "Validating: ${manifest}"
        if kubectl apply --dry-run=client -f "${manifest}" &> /dev/null; then
            log_info "✅ Valid: $(basename "${manifest}")"
        else
            log_warn "⚠️  Validation issues: $(basename "${manifest}")"
            kubectl apply --dry-run=client -f "${manifest}"
        fi
    done

    log_info "Manifest validation complete!"
}

deploy_moltbook() {
    log_info "Deploying Moltbook to ardenone-cluster..."

    # Use kustomize if available, otherwise apply directory
    if command -v kustomize &> /dev/null; then
        log_info "Using kustomize to build manifests..."
        kustomize build "${MOLTBOOK_K8S_DIR}" | kubectl apply -f -
    elif kubectl apply --help | grep -q kustomize; then
        log_info "Using kubectl kustomize to build manifests..."
        kubectl apply -k "${MOLTBOOK_K8S_DIR}"
    else
        log_warn "Kustomize not available, applying manifests directory..."
        kubectl apply -f "${MOLTBOOK_K8S_DIR}"
    fi

    log_info "Moltbook deployment initiated!"
}

verify_deployment() {
    log_info "Verifying deployment..."

    # Wait for deployments to be ready
    log_info "Waiting for deployments to roll out..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/moltbook-api \
        deployment/moltbook-frontend \
        -n moltbook || {
        log_warn "Some deployments may not be ready yet"
        log_info "Check status with: kubectl get deployments -n moltbook"
    }

    # Show deployment status
    log_info "Deployment status:"
    kubectl get deployments -n moltbook

    log_info "Pods status:"
    kubectl get pods -n moltbook

    log_info "Services status:"
    kubectl get services -n moltbook

    log_info "IngressRoutes status:"
    kubectl get ingressroutes -n moltbook 2>/dev/null || log_info "No IngressRoutes found (Traefik may not be installed)"
}

print_success() {
    log_info "========================================"
    log_info "🎉 Moltbook deployment complete!"
    log_info "========================================"
    echo ""
    log_info "Next steps:"
    log_info "1. Check pod logs:"
    log_info "   kubectl logs -n moltbook -l app=moltbook-api --tail=50"
    log_info ""
    log_info "2. Get ingress URL:"
    log_info "   kubectl get ingressroute -n moltbook"
    log_info ""
    log_info "3. Monitor health:"
    log_info "   kubectl get pods -n moltbook -w"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    log_info "=========================================="
    log_info "Moltbook Deployment Script"
    log_info "=========================================="
    echo ""

    check_prerequisites
    echo ""

    verify_manifests
    echo ""

    deploy_moltbook
    echo ""

    # Give deployments time to start
    log_info "Waiting 10 seconds for deployments to initialize..."
    sleep 10
    echo ""

    verify_deployment
    echo ""

    print_success
}

# Run main function
main "$@"
