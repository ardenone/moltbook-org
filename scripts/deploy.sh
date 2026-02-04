#!/bin/bash
set -e

# Moltbook Deployment Script
# This script deploys the Moltbook platform to ardenone-cluster

NAMESPACE="moltbook"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Moltbook Deployment Script"
echo "=============================="
echo ""

# Check if we can connect to cluster
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Cannot connect to cluster or namespace $NAMESPACE does not exist"
    echo "Creating namespace..."
    kubectl apply -f "$PROJECT_DIR/k8s/namespace/moltbook-namespace.yml"
fi

echo "📋 Deployment Steps:"
echo "  1. Namespace"
echo "  2. Secrets (SealedSecrets)"
echo "  3. Database (PostgreSQL CNPG)"
echo "  4. Redis (optional)"
echo "  5. Database Schema Init"
echo "  6. API Backend"
echo "  7. Frontend"
echo "  8. Ingress Routes"
echo "  9. ArgoCD Application"
echo ""

read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

# 1. Namespace
echo ""
echo "📦 [1/9] Creating namespace..."
kubectl apply -f "$PROJECT_DIR/k8s/namespace/moltbook-namespace.yml"

# 2. Secrets
echo ""
echo "🔐 [2/9] Applying secrets..."
if [ -d "$PROJECT_DIR/k8s/secrets" ]; then
    kubectl apply -f "$PROJECT_DIR/k8s/secrets/*-sealedsecret.yml" 2>/dev/null || echo "⚠️  No SealedSecrets found. Please run ./scripts/generate-sealed-secrets.sh first"
else
    echo "⚠️  No secrets directory found. Please run ./scripts/generate-sealed-secrets.sh first"
fi

# 3. PostgreSQL
echo ""
echo "🐘 [3/9] Deploying PostgreSQL cluster..."
kubectl apply -f "$PROJECT_DIR/k8s/database/postgres-cluster.yml"
echo "⏳ Waiting for PostgreSQL to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l cnpg.io/pod-role=instance -n "$NAMESPACE" --timeout=300s || echo "⚠️  PostgreSQL pods not ready yet. Check with: kubectl get pods -n $NAMESPACE"

# 4. Redis
echo ""
echo "📦 [4/9] Deploying Redis..."
kubectl apply -f "$PROJECT_DIR/k8s/database/redis-deployment.yml"

# 5. Database Schema
echo ""
echo "🗄️  [5/9] Initializing database schema..."
kubectl apply -f "$PROJECT_DIR/k8s/database/schema-configmap.yml"
kubectl apply -f "$PROJECT_DIR/k8s/database/schema-init-job.yml"

# 6. API
echo ""
echo "⚙️  [6/9] Deploying API backend..."
kubectl apply -f "$PROJECT_DIR/k8s/api/deployment.yml"
kubectl apply -f "$PROJECT_DIR/k8s/api/service.yml"

# 7. Frontend
echo ""
echo "🎨 [7/9] Deploying frontend..."
kubectl apply -f "$PROJECT_DIR/k8s/frontend/deployment.yml"
kubectl apply -f "$PROJECT_DIR/k8s/frontend/service.yml"

# 8. Ingress
echo ""
echo "🌐 [8/9] Configuring ingress routes..."
kubectl apply -f "$PROJECT_DIR/k8s/ingress/api-ingressroute.yml"
kubectl apply -f "$PROJECT_DIR/k8s/ingress/frontend-ingressroute.yml"

# 9. ArgoCD
echo ""
echo "🔄 [9/9] Creating ArgoCD application..."
kubectl apply -f "$PROJECT_DIR/k8s/argocd/moltbook-application.yml"

echo ""
echo "✨ Deployment complete!"
echo ""
echo "📊 Check deployment status:"
echo "   kubectl get pods -n $NAMESPACE"
echo "   kubectl get svc -n $NAMESPACE"
echo "   kubectl get ingressroute -n $NAMESPACE"
echo ""
echo "🌐 Access the application:"
echo "   Frontend: https://moltbook.ardenone.com"
echo "   API: https://api-moltbook.ardenone.com"
echo "   API Health: https://api-moltbook.ardenone.com/api/v1/health"
echo ""
echo "📝 View logs:"
echo "   kubectl logs -f deployment/moltbook-api -n $NAMESPACE"
echo "   kubectl logs -f deployment/moltbook-frontend -n $NAMESPACE"
