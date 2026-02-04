#!/usr/bin/env bash
# ============================================================================
# ArgoCD Installation Readiness Verification Script
# ============================================================================
#
# This script verifies that the prerequisites for ArgoCD installation are met.
# Run this BEFORE attempting to install ArgoCD in ardenone-cluster.
#
# Usage:
#   ./k8s/verify-argocd-ready.sh
#
# Exit codes:
#   0 - All prerequisites met, ready to install ArgoCD
#   1 - Missing prerequisites, cannot install ArgoCD
#
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "========================================================================"
echo "ArgoCD Installation Readiness Verification"
echo "========================================================================"
echo ""

# Check 1: Can create namespaces
echo -n "Checking namespace creation permission... "
if kubectl auth can-i create namespaces 2>/dev/null; then
    check_pass "Can create namespaces"
else
    check_fail "Cannot create namespaces - RBAC not applied"
fi

# Check 2: Can create CRDs
echo -n "Checking CRD creation permission... "
if kubectl auth can-i create customresourcedefinitions 2>/dev/null; then
    check_pass "Can create CRDs"
else
    check_fail "Cannot create CRDs - RBAC not applied"
fi

# Check 3: Can create ClusterRoles
echo -n "Checking ClusterRole creation permission... "
if kubectl auth can-i create clusterroles 2>/dev/null; then
    check_pass "Can create ClusterRoles"
else
    check_fail "Cannot create ClusterRoles - RBAC not applied"
fi

# Check 4: Can create ClusterRoleBindings
echo -n "Checking ClusterRoleBinding creation permission... "
if kubectl auth can-i create clusterrolebindings 2>/dev/null; then
    check_pass "Can create ClusterRoleBindings"
else
    check_fail "Cannot create ClusterRoleBindings - RBAC not applied"
fi

# Check 5: argocd namespace exists or can be created
echo -n "Checking argocd namespace... "
if kubectl get namespace argocd >/dev/null 2>&1; then
    check_pass "argocd namespace exists"
elif kubectl auth can-i create namespaces 2>/dev/null; then
    check_pass "argocd namespace can be created"
else
    check_fail "argocd namespace does not exist and cannot be created"
fi

# Check 6: moltbook namespace exists or can be created
echo -n "Checking moltbook namespace... "
if kubectl get namespace moltbook >/dev/null 2>&1; then
    check_pass "moltbook namespace exists"
elif kubectl auth can-i create namespaces 2>/dev/null; then
    check_pass "moltbook namespace can be created"
else
    check_fail "moltbook namespace does not exist and cannot be created"
fi

# Check 7: argocd-installer ClusterRole exists
echo -n "Checking argocd-installer ClusterRole... "
if kubectl get clusterrole argocd-installer >/dev/null 2>&1; then
    check_pass "argocd-installer ClusterRole exists"
else
    check_warn "argocd-installer ClusterRole not found (may need ARGOCD_INSTALL_REQUEST.yml)"
fi

# Check 8: devpod-argocd-installer ClusterRoleBinding exists
echo -n "Checking devpod-argocd-installer ClusterRoleBinding... "
if kubectl get clusterrolebinding devpod-argocd-installer >/dev/null 2>&1; then
    check_pass "devpod-argocd-installer ClusterRoleBinding exists"
else
    check_warn "devpod-argocd-installer ClusterRoleBinding not found (may need ARGOCD_INSTALL_REQUEST.yml)"
fi

# Check 9: ArgoCD already installed?
echo -n "Checking if ArgoCD is already installed... "
if kubectl get namespace argocd >/dev/null 2>&1 && \
   kubectl get deployment -n argocd argocd-server >/dev/null 2>&1; then
    check_warn "ArgoCD appears to already be installed"
else
    echo -e "${YELLOW}⚠ INFO${NC}: ArgoCD not yet installed (expected)"
fi

echo ""
echo "========================================================================"
echo "Summary"
echo "========================================================================"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ READY${NC}: All prerequisites met. You can now install ArgoCD:"
    echo ""
    echo "  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    echo "  kubectl apply -f k8s/argocd-application.yml"
    echo ""
    exit 0
else
    echo -e "${RED}✗ NOT READY${NC}: Prerequisites not met. Cluster-admin must apply:"
    echo ""
    echo "  kubectl apply -f k8s/ARGOCD_INSTALL_REQUEST.yml"
    echo ""
    echo "Then run this script again to verify."
    echo ""
    exit 1
fi
