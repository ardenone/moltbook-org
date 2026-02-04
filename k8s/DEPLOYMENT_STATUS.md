# Moltbook Deployment Status - ardenone-cluster

**Status:** READY TO DEPLOY (Blocked on RBAC permissions)

**Date:** 2026-02-04

---

## Summary

All Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster are complete and ready. The deployment cannot proceed because the `devpod` ServiceAccount lacks RBAC permissions to create resources in the `moltbook` namespace.

---

## Deployment Components

### 1. Namespace and RBAC
- [x] `k8s/namespace/moltbook-namespace.yml` - Namespace definition
- [x] `k8s/namespace/moltbook-rbac.yml` - Role and RoleBinding for devpod ServiceAccount
- [x] `k8s/NAMESPACE_REQUEST.yml` - Standalone namespace creation request

### 2. Secrets (SealedSecrets)
- [x] `k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml` - PostgreSQL superuser credentials
- [x] `k8s/secrets/moltbook-db-credentials-sealedsecret.yml` - Database app user credentials + JWT_SECRET
- [x] `k8s/secrets/moltbook-api-sealedsecret.yml` - API secrets (DATABASE_URL, JWT_SECRET, etc.)

### 3. Database (CNPG)
- [x] `k8s/database/cluster.yml` - CloudNativePG Cluster (1 instance, 10Gi storage)
- [x] `k8s/database/schema-configmap.yml` - Database schema SQL
- [x] `k8s/database/schema-init-job.yml` - Idempotent Deployment for schema initialization
- [x] `k8s/database/postgres-app-user-secret-template.yml` - Template (not deployed)

### 4. Cache (Redis)
- [x] `k8s/redis/deployment.yml` - Redis 7-alpine Deployment (1 replica)
- [x] `k8s/redis/service.yml` - ClusterIP Service on port 6379

### 5. API Backend
- [x] `k8s/api/configmap.yml` - Configuration (PORT, NODE_ENV, BASE_URL, REDIS_URL, CORS_ORIGINS)
- [x] `k8s/api/deployment.yml` - Deployment (2 replicas, with init container for DB migrations)
- [x] `k8s/api/service.yml` - ClusterIP Service on port 80

### 6. Frontend (Next.js)
- [x] `k8s/frontend/configmap.yml` - Configuration (NEXT_PUBLIC_API_URL)
- [x] `k8s/frontend/deployment.yml` - Deployment (2 replicas)
- [x] `k8s/frontend/service.yml` - ClusterIP Service on port 80

### 7. Ingress (Traefik)
- [x] `k8s/ingress/frontend-ingressroute.yml` - Host: `moltbook.ardenone.com`
- [x] `k8s/ingress/api-ingressroute.yml` - Host: `api-moltbook.ardenone.com`

### 8. GitOps (ArgoCD)
- [x] `k8s/argocd-application.yml` - ArgoCD Application manifest

### 9. Kustomization
- [x] `k8s/kustomization.yml` - Main kustomization with namespace
- [x] `k8s/kustomization-no-namespace.yml` - Alternative without namespace

---

## Blocker Details

**Bead ID:** mo-daw
**Priority:** 0 (Critical)
**Title:** Fix: Apply RBAC permissions for moltbook namespace deployment

### Issue
The `moltbook` namespace exists but the `devpod` ServiceAccount (`system:serviceaccount:devpod:default`) cannot create resources in it. Permission tests show:

```
kubectl auth can-i create deployments -n moltbook
# Response: no
```

### Required Action
A cluster administrator must apply the RBAC manifest:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-rbac.yml
```

This will create:
- Role: `moltbook-deployer` (grants permissions for deployments, services, CNPG clusters, IngressRoutes, etc.)
- RoleBinding: `moltbook-deployer-binding` (binds role to `devpod:default` ServiceAccount)

### After RBAC is Applied

Once the RBAC is in place, deployment can proceed with:

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

Or via ArgoCD:

```bash
kubectl apply -f k8s/argocd-application.yml
```

---

## Expected Deployment Architecture

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance)
  │   └─ moltbook-postgres-rw Service (ReadWrite)
  │
  ├─ moltbook-redis (Deployment, 1 replica)
  │   └─ moltbook-redis Service
  │
  ├─ moltbook-db-init (Deployment, 1 replica)
  │   └─ Runs schema initialization once
  │
  ├─ moltbook-api (Deployment, 2 replicas)
  │   └─ moltbook-api Service (port 80)
  │       └─ IngressRoute: api-moltbook.ardenone.com
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service (port 80)
          └─ IngressRoute: moltbook.ardenone.com
```

---

## Access Points (Post-Deployment)

- **Frontend:** https://moltbook.ardenone.com
- **API:** https://api-moltbook.ardenone.com
- **API Health:** https://api-moltbook.ardenone.com/health

---

## Related Beads

- **mo-saz** (this bead): Implementation: Deploy Moltbook platform to ardenone-cluster
- **mo-daw** (blocker): Fix: Apply RBAC permissions for moltbook namespace deployment
