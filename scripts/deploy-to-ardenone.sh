#!/bin/bash
# Deployment script for Moltbook platform to ardenone-cluster
# This script requires cluster-admin privileges or proper RBAC setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Moltbook Deployment to ardenone-cluster"
echo "========================================="
echo ""

# Check if we have necessary permissions
echo "Checking permissions..."
if kubectl auth can-i create namespaces 2>/dev/null; then
    echo "✓ Has namespace creation permission"
else
    echo "✗ Missing namespace creation permission"
    echo "  This script requires cluster-admin privileges or pre-created namespace with RBAC"
    echo ""
    echo "Option 1: Run as cluster-admin"
    echo "Option 2: Have a cluster admin run:"
    echo "  kubectl create namespace moltbook"
    echo "  kubectl apply -f ${PROJECT_DIR}/k8s/namespace/moltbook-rbac.yml"
    echo ""
    exit 1
fi

# Check if required operators are installed
echo "Checking required operators..."

if kubectl get crd clusters.postgresql.cnpg.io &>/dev/null; then
    echo "✓ CloudNativePG operator is installed"
else
    echo "✗ CloudNativePG operator not found"
    exit 1
fi

if kubectl get crd sealedsecrets.bitnami.com &>/dev/null; then
    echo "✓ SealedSecrets operator is installed"
else
    echo "✗ SealedSecrets operator not found"
    exit 1
fi

if kubectl get crd ingressroutes.traefik.io &>/dev/null; then
    echo "✓ Traefik IngressRoute CRD is installed"
else
    echo "✗ Traefik IngressRoute CRD not found"
    exit 1
fi

echo ""

# Step 1: Create namespace
echo "Step 1: Creating namespace..."
kubectl create namespace moltbook --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Apply RBAC
echo "Step 2: Applying RBAC..."
kubectl apply -f "${PROJECT_DIR}/k8s/namespace/moltbook-rbac.yml"

# Step 3: Apply SealedSecrets
echo "Step 3: Applying SealedSecrets..."
kubectl apply -f "${PROJECT_DIR}/k8s/secrets/moltbook-api-sealedsecret.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/secrets/moltbook-db-credentials-sealedsecret.yml"

# Step 4: Apply database manifests
echo "Step 4: Applying database manifests..."
kubectl apply -f "${PROJECT_DIR}/k8s/database/service.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/database/schema-configmap.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/database/cluster.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/database/schema-init-deployment.yml"

# Step 5: Apply Redis
echo "Step 5: Applying Redis..."
kubectl apply -f "${PROJECT_DIR}/k8s/redis/configmap.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/redis/service.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/redis/deployment.yml"

# Step 6: Apply API
echo "Step 6: Applying API..."
kubectl apply -f "${PROJECT_DIR}/k8s/api/configmap.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/api/service.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/api/deployment.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/api/ingressroute.yml"

# Step 7: Apply Frontend
echo "Step 7: Applying Frontend..."
kubectl apply -f "${PROJECT_DIR}/k8s/frontend/configmap.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/frontend/service.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/frontend/deployment.yml"
kubectl apply -f "${PROJECT_DIR}/k8s/frontend/ingressroute.yml"

echo ""
echo "========================================="
echo "Deployment complete!"
echo "========================================="
echo ""
echo "Waiting for pods to be ready..."
echo ""

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s \
    deployment/moltbook-db-init \
    deployment/moltbook-redis \
    deployment/moltbook-api \
    deployment/moltbook-frontend \
    -n moltbook || true

# Wait for CNPG cluster
echo "Waiting for PostgreSQL cluster..."
kubectl wait --for=condition=ready --timeout=300s \
    cluster/moltbook-postgres -n moltbook || true

echo ""
echo "========================================="
echo "Checking deployment status..."
echo "========================================="
echo ""

kubectl get pods -n moltbook

echo ""
echo "Services:"
kubectl get svc -n moltbook

echo ""
echo "IngressRoutes:"
kubectl get ingressroute -n moltbook

echo ""
echo "========================================="
echo "Access URLs:"
echo "========================================="
echo "  Frontend: https://moltbook.ardenone.com"
echo "  API:      https://api-moltbook.ardenone.com"
echo ""
