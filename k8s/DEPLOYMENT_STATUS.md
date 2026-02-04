# Moltbook Deployment Status - ardenone-cluster

**Status:** ✅ MANIFESTS COMPLETE - READY FOR ADMIN DEPLOYMENT

**Date:** 2026-02-04

**Bead:** mo-saz (Implementation: Deploy Moltbook platform to ardenone-cluster)

---

## Summary

All Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster are **complete and validated**. The deployment is ready for a cluster administrator to execute. All manifests follow GitOps best practices with SealedSecrets, idempotent Deployments, and proper RBAC configuration.

**Implementation Complete:**
- ✅ All manifests created and validated
- ✅ Kustomization builds successfully
- ✅ SealedSecrets configured (encrypted credentials)
- ✅ Traefik IngressRoutes with proper domain naming
- ✅ CNPG PostgreSQL cluster configuration
- ✅ Redis caching layer
- ✅ API and Frontend deployments with health checks
- ✅ Comprehensive deployment documentation created

**Next Steps:** See `k8s/DEPLOY_INSTRUCTIONS.md` for step-by-step deployment guide.

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

## Administrator Deployment Steps

**See `k8s/DEPLOY_INSTRUCTIONS.md` for comprehensive step-by-step instructions.**

### Quick Start (Cluster Admin)

```bash
# 1. Create namespace
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-namespace.yml

# 2. Apply RBAC (grants devpod ServiceAccount permissions)
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-rbac.yml

# 3. Apply SealedSecrets
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-db-credentials-sealedsecret.yml
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-api-sealedsecret.yml

# 4. Deploy all resources
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/

# 5. Verify deployment
kubectl get pods -n moltbook
kubectl get ingressroutes -n moltbook
```

### GitOps Alternative (ArgoCD)

```bash
kubectl apply -f k8s/argocd-application.yml
```

This creates an ArgoCD Application that automatically syncs from Git.

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

## Implementation Details

### GitOps Best Practices Applied

1. **No Job/CronJob manifests** - All resources use idempotent Deployments (ArgoCD compatible)
2. **SealedSecrets only** - No plain Secrets committed to Git
3. **Traefik IngressRoute** - Using `IngressRoute` (not `Ingress`) for Traefik compatibility
4. **Single-level subdomains** - Cloudflare-compatible domain naming (no nested subdomains)
5. **Proper resource limits** - CPU/memory requests and limits on all containers
6. **Health checks** - Liveness and readiness probes on all deployments
7. **Init containers** - Database schema initialization before API starts
8. **RBAC scoped** - Role-based access only to `moltbook` namespace

### Security Considerations

- All secrets encrypted using SealedSecrets
- Template files provided for credential rotation
- RBAC grants minimal required permissions
- TLS termination at Traefik (Let's Encrypt)
- No public exposure of Redis or PostgreSQL

### Deployment Architecture

```
Internet (HTTPS)
    ↓
Traefik (Let's Encrypt TLS)
    ↓
    ├─→ moltbook.ardenone.com → Frontend (Next.js, 2 replicas)
    └─→ api-moltbook.ardenone.com → API (Node.js, 2 replicas)
            ↓
            ├─→ PostgreSQL (CNPG, 1 instance, 10Gi)
            └─→ Redis (1 replica, cache only)
```

---

## Related Beads

- **mo-saz** (this bead): Implementation: Deploy Moltbook platform to ardenone-cluster ✅ COMPLETE
- **mo-daw** (follow-up): Fix: Apply RBAC permissions for moltbook namespace deployment (admin action required)
