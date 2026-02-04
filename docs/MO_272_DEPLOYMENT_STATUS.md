# Moltbook Deployment Status - mo-272

**Task:** Deploy: Apply Moltbook manifests to ardenone-cluster
**Date:** 2026-02-04
**Status:** BLOCKED by RBAC permissions

## Summary

All Kubernetes manifests for Moltbook are **complete and ready** for deployment to ardenone-cluster. The deployment is blocked because the devpod ServiceAccount lacks permissions to create namespaces.

## Manifests Ready

All required Kubernetes manifests exist in `/home/coder/Research/moltbook-org/k8s/`:

### Core Components
- **Frontend Deployment** (`frontend/deployment.yml`) - Next.js 14 app, 2 replicas
- **API Deployment** (`api/deployment.yml`) - Express.js API, 2 replicas
- **Database** (`database/cluster.yml`) - CloudNativePG PostgreSQL cluster
- **Redis** (`redis/deployment.yml`) - Redis cache layer

### Networking
- **Frontend Service** (`frontend/service.yml`) - ClusterIP on port 80
- **API Service** (`api/service.yml`) - ClusterIP on port 80
- **Database Service** (`database/service.yml`) - ClusterIP for PostgreSQL
- **Redis Service** (`redis/service.yml`) - ClusterIP on port 6379
- **Frontend IngressRoute** (`frontend/ingressroute.yml`) - Traefik route for moltbook.ardenone.com
- **API IngressRoute** (`api/ingressroute.yml`) - Traefik route for api-moltbook.ardenone.com

### Configuration
- **Frontend ConfigMap** (`frontend/configmap.yml`) - NEXT_PUBLIC_API_URL
- **API ConfigMap** (`api/configmap.yml`) - PORT, NODE_ENV, BASE_URL, REDIS_URL, CORS_ORIGINS
- **Database Schema ConfigMap** (`database/schema-configmap.yml`) - SQL schema
- **Redis ConfigMap** (`redis/configmap.yml`) - Redis configuration

### Secrets (SealedSecrets - encrypted, safe for Git)
- **API Secrets** (`secrets/moltbook-api-sealedsecret.yml`) - DATABASE_URL, JWT_SECRET
- **DB Credentials** (`secrets/moltbook-db-credentials-sealedsecret.yml`) - App credentials
- **PostgreSQL Superuser** (`secrets/moltbook-postgres-superuser-sealedsecret.yml`) - Superuser credentials

### RBAC & Namespace
- **Namespace** (`namespace/moltbook-namespace.yml`) - moltbook namespace
- **RBAC** (`namespace/moltbook-rbac.yml`) - Role and RoleBinding for devpod
- **ClusterRoleBinding** (`namespace/devpod-namespace-creator-rbac.yml`) - Grants namespace creation permission

### ArgoCD
- **ArgoCD Application** (`argocd-application.yml`) - ArgoCD Application manifest for GitOps

### Kustomization
- **Kustomization** (`kustomization.yml`) - Complete manifest orchestration

## Blocker: RBAC Permissions

**Issue:** The devpod ServiceAccount cannot create the `moltbook` namespace.

**Error:**
```
Error from server (Forbidden): error when creating "/home/coder/Research/moltbook-org/k8s/namespace/moltbook-namespace.yml": namespaces is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "namespaces" in API group "" at the cluster scope
```

**Resolution:**

A cluster administrator must apply the ClusterRoleBinding manifest:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml
```

This grants the devpod ServiceAccount permission to:
- Create namespaces
- Manage roles and rolebindings
- Create Traefik middlewares

## Related Beads

- **mo-1k7c** (P0) - Blocker: Apply ClusterRoleBinding for devpod namespace creation

## Deployment Steps (After RBAC is Resolved)

1. Apply namespace creation RBAC (cluster admin required):
   ```bash
   kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
   ```

2. Create namespace and RBAC:
   ```bash
   kubectl apply -f k8s/namespace/moltbook-namespace.yml
   kubectl apply -f k8s/namespace/moltbook-rbac.yml
   ```

3. Apply all manifests:
   ```bash
   kubectl apply -k k8s/
   ```

4. Verify deployment:
   ```bash
   kubectl get pods -n moltbook
   kubectl get all -n moltbook
   ```

## Container Images

The deployment references these container images:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

**Note:** Ensure these images are built and pushed to GHCR before deployment.

## External Access

After deployment, the following URLs will be accessible:
- Frontend: `https://moltbook.ardenone.com`
- API: `https://api-moltbook.ardenone.com`
- API Health Check: `https://api-moltbook.ardenone.com/health`
