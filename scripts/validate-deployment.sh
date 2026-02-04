#!/bin/bash
# Moltbook Deployment Validation Script
# Validates Kubernetes manifests and checks deployment readiness

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Moltbook Deployment Validation${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Check if we're in the correct directory
if [ ! -d "k8s" ]; then
    echo -e "${RED}Error: k8s directory not found. Run this script from the moltbook-org root.${NC}"
    exit 1
fi

# Validation counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

function check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    : $((CHECKS_PASSED++))
}

function check_fail() {
    echo -e "${RED}✗${NC} $1"
    : $((CHECKS_FAILED++))
}

function check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    : $((WARNINGS++))
}

echo -e "${BLUE}1. Validating Kubernetes Tools${NC}"
echo "--------------------------------"

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n1)
    check_pass "kubectl installed: $KUBECTL_VERSION"
else
    check_fail "kubectl not installed"
fi

# Check kustomize (via kubectl)
if kubectl kustomize --help &> /dev/null; then
    check_pass "kustomize available (via kubectl)"
else
    check_fail "kustomize not available"
fi

echo

echo -e "${BLUE}2. Validating Kustomization Build${NC}"
echo "--------------------------------"

# Build kustomization
if kubectl kustomize k8s/ > /dev/null 2>&1; then
    MANIFEST_LINES=$(kubectl kustomize k8s/ | wc -l)
    check_pass "Kustomization builds successfully ($MANIFEST_LINES lines)"
else
    check_fail "Kustomization build failed"
    kubectl kustomize k8s/ 2>&1 || true
fi

echo

echo -e "${BLUE}3. Validating Required Components${NC}"
echo "--------------------------------"

# Check for required manifests
REQUIRED_FILES=(
    "k8s/namespace/moltbook-namespace.yml"
    "k8s/namespace/moltbook-rbac.yml"
    "k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml"
    "k8s/secrets/moltbook-db-credentials-sealedsecret.yml"
    "k8s/secrets/moltbook-api-sealedsecret.yml"
    "k8s/database/cluster.yml"
    "k8s/database/schema-configmap.yml"
    "k8s/database/schema-init-deployment.yml"
    "k8s/redis/deployment.yml"
    "k8s/api/deployment.yml"
    "k8s/api/service.yml"
    "k8s/api/ingressroute.yml"
    "k8s/frontend/deployment.yml"
    "k8s/frontend/service.yml"
    "k8s/frontend/ingressroute.yml"
    "k8s/argocd-application.yml"
    "k8s/kustomization.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Found: $file"
    else
        check_fail "Missing: $file"
    fi
done

echo

echo -e "${BLUE}4. Validating Manifest Content${NC}"
echo "--------------------------------"

# Check for proper domain naming (no nested subdomains)
if grep -r "Host(\`[^.]*\.[^.]*\.[^.]*\." k8s/ --include="*.yml" 2>/dev/null; then
    check_warn "Found nested subdomains (Cloudflare may not support)"
else
    check_pass "No nested subdomains found (Cloudflare compatible)"
fi

# Check for Job/CronJob manifests (should not exist)
if grep -r "kind: Job" k8s/ --include="*.yml" 2>/dev/null | grep -v "# kind: Job"; then
    check_fail "Found Job manifest (should use Deployment for ArgoCD compatibility)"
elif grep -r "kind: CronJob" k8s/ --include="*.yml" 2>/dev/null | grep -v "# kind: CronJob"; then
    check_fail "Found CronJob manifest (should use Deployment for ArgoCD compatibility)"
else
    check_pass "No Job/CronJob manifests (ArgoCD compatible)"
fi

# Check for plain Secrets (should only have SealedSecrets)
if grep -r "kind: Secret$" k8s/ --include="*.yml" 2>/dev/null | grep -v template | grep -v "# kind: Secret"; then
    check_warn "Found plain Secret manifests (should use SealedSecret)"
else
    check_pass "No plain Secret manifests (using SealedSecret)"
fi

# Check for correct image references
if grep -r "ghcr.io/ardenone/moltbook-api" k8s/ --include="*.yml" > /dev/null 2>&1; then
    check_pass "API image reference correct (ghcr.io/ardenone/moltbook-api)"
else
    check_fail "API image reference incorrect or missing"
fi

if grep -r "ghcr.io/ardenone/moltbook-frontend" k8s/ --include="*.yml" > /dev/null 2>&1; then
    check_pass "Frontend image reference correct (ghcr.io/ardenone/moltbook-frontend)"
else
    check_fail "Frontend image reference incorrect or missing"
fi

# Check for Traefik IngressRoute (not Ingress)
if grep -r "kind: IngressRoute" k8s/ --include="*.yml" > /dev/null 2>&1; then
    check_pass "Using Traefik IngressRoute (correct)"
else
    check_fail "IngressRoute not found (should use Traefik IngressRoute)"
fi

# Check for proper domain names
if grep "api-moltbook.ardenone.com" k8s/api/ingressroute.yml > /dev/null 2>&1; then
    check_pass "API domain correct (api-moltbook.ardenone.com)"
else
    check_fail "API domain incorrect or missing"
fi

if grep "moltbook.ardenone.com" k8s/frontend/ingressroute.yml > /dev/null 2>&1; then
    check_pass "Frontend domain correct (moltbook.ardenone.com)"
else
    check_fail "Frontend domain incorrect or missing"
fi

echo

echo -e "${BLUE}5. Checking Cluster Prerequisites${NC}"
echo "--------------------------------"

# Check if namespace exists
if kubectl get namespace moltbook &> /dev/null; then
    check_pass "Namespace 'moltbook' exists"

    # Check if pods are running
    POD_COUNT=$(kubectl get pods -n moltbook --no-headers 2>/dev/null | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        check_pass "Found $POD_COUNT pod(s) in moltbook namespace"
        kubectl get pods -n moltbook 2>/dev/null || true
    else
        check_warn "No pods found in moltbook namespace"
    fi
else
    check_warn "Namespace 'moltbook' does not exist (create with: kubectl apply -f k8s/namespace/moltbook-namespace.yml)"
fi

# Check if CNPG operator is available
if kubectl get crd clusters.postgresql.cnpg.io &> /dev/null; then
    check_pass "CNPG operator available (CRD found)"
else
    check_warn "CNPG operator not found (required for PostgreSQL)"
fi

# Check if Sealed Secrets controller is available
if kubectl get crd sealedsecrets.bitnami.com &> /dev/null; then
    check_pass "Sealed Secrets controller available (CRD found)"
else
    check_warn "Sealed Secrets controller not found (required for secrets)"
fi

# Check if Traefik is available
if kubectl get ingressroute -A &> /dev/null 2>&1; then
    check_pass "Traefik CRD available (IngressRoute supported)"
else
    check_warn "Traefik IngressRoute CRD not found (required for ingress)"
fi

echo

echo -e "${BLUE}6. Validation Summary${NC}"
echo "--------------------------------"
echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
echo

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Ensure namespace is created:"
    echo "   kubectl apply -f k8s/namespace/moltbook-namespace.yml"
    echo
    echo "2. Apply RBAC permissions:"
    echo "   kubectl apply -f k8s/namespace/moltbook-rbac.yml"
    echo
    echo "3. Deploy using kustomize:"
    echo "   kubectl apply -k k8s/"
    echo
    echo "4. Or use ArgoCD for GitOps:"
    echo "   kubectl apply -f k8s/argocd-application.yml"
    echo
    echo -e "${GREEN}Deployment manifests are ready!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please fix the issues above.${NC}"
    exit 1
fi
