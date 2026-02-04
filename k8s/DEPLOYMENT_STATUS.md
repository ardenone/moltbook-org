# Moltbook Deployment Status - ardenone-cluster

**Status:** ✅ MANIFESTS DEPLOYED TO CLUSTER-CONFIGURATION - BLOCKED ON CLUSTER ADMIN RBAC

**Date:** 2026-02-04 17:05 UTC

**Bead:** mo-saz (Implementation: Deploy Moltbook platform to ardenone-cluster)

**Test Results:** ✅ API: 14/14 passing | ✅ Frontend: 36/36 passing

**Deployment Progress:**
- ✅ All manifests committed to cluster-configuration repo: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`
- ✅ GitOps-ready manifests prepared for ArgoCD or manual kubectl deployment
- ⚠️ ArgoCD namespace exists but controller pods not running (ArgoCD not operational)
- ❌ Manual kubectl apply blocked by namespace creation permissions

**Blockers:**
1. **Namespace Creation Blocked** - DevPod ServiceAccount cannot create `moltbook` namespace
2. **RBAC Required** - ClusterRoleBinding `devpod-namespace-creator` must be applied by cluster admin (see mo-382)
3. **ArgoCD Not Operational** - ArgoCD namespace exists but no running pods

---

## Summary

All Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster are **complete and validated**. The deployment is ready for a cluster administrator to execute. All manifests follow GitOps best practices with SealedSecrets, idempotent Deployments, and proper RBAC configuration.

**Implementation Complete:**
- ✅ All manifests created and validated
- ✅ Manifests committed to cluster-configuration repo at `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`
- ✅ Kustomization builds successfully (1050 lines)
- ✅ SealedSecrets configured (encrypted credentials)
- ✅ Traefik IngressRoutes with proper domain naming
- ✅ CNPG PostgreSQL cluster configuration
- ✅ Redis caching layer
- ✅ API and Frontend deployments with health checks
- ✅ Traefik middlewares for security, CORS, and rate limiting
- ✅ Comprehensive deployment documentation created

**Manifest Locations:**
- **moltbook-org repo:** `/home/coder/Research/moltbook-org/k8s/` (development/testing)
- **cluster-configuration repo:** `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/` (production deployment)

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
- [x] `k8s/database/service.yml` - Explicit service definition (CNPG auto-creates services)
- [x] `k8s/database/schema-configmap.yml` - Database schema SQL
- [x] `k8s/database/schema-init-deployment.yml` - Idempotent Deployment for schema initialization

### 4. Cache (Redis)
- [x] `k8s/redis/configmap.yml` - Redis configuration
- [x] `k8s/redis/deployment.yml` - Redis 7-alpine Deployment (1 replica)
- [x] `k8s/redis/service.yml` - ClusterIP Service on port 6379

### 5. API Backend
- [x] `k8s/api/configmap.yml` - Configuration (PORT, NODE_ENV, BASE_URL, REDIS_URL, CORS_ORIGINS)
- [x] `k8s/api/deployment.yml` - Deployment (2 replicas, with init container for DB migrations)
- [x] `k8s/api/service.yml` - ClusterIP Service on port 80
- [x] `k8s/api/ingressroute.yml` - IngressRoute with CORS and rate limiting middlewares

### 6. Frontend (Next.js)
- [x] `k8s/frontend/configmap.yml` - Configuration (NEXT_PUBLIC_API_URL)
- [x] `k8s/frontend/deployment.yml` - Deployment (2 replicas)
- [x] `k8s/frontend/service.yml` - ClusterIP Service on port 80
- [x] `k8s/frontend/ingressroute.yml` - IngressRoute with security headers middleware

### 7. Ingress (Traefik)
- [x] `k8s/api/ingressroute.yml` - Host: `api-moltbook.ardenone.com`
  - CORS middleware for cross-origin requests
  - Rate limiting middleware (100 req/min average, 50 burst)
- [x] `k8s/frontend/ingressroute.yml` - Host: `moltbook.ardenone.com`
  - Security headers middleware (X-Frame-Options, CSP, etc.)

### 8. GitOps (ArgoCD)
- [x] `k8s/argocd-application.yml` - ArgoCD Application manifest

### 9. Kustomization
- [x] `k8s/kustomization.yml` - Main kustomization with namespace (1050 lines)
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
  │   ├─ moltbook-postgres-rw Service (ReadWrite, auto-created by CNPG)
  │   ├─ moltbook-postgres-ro Service (ReadOnly, auto-created by CNPG)
  │   └─ moltbook-postgres Service (explicit service definition)
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
  │           ├─ CORS middleware
  │           └─ Rate limiting middleware (100/min)
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service (port 80)
          └─ IngressRoute: moltbook.ardenone.com
              └─ Security headers middleware
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
9. **Traefik middlewares** - Security headers, CORS, and rate limiting

### Security Considerations

- All secrets encrypted using SealedSecrets
- Template files provided for credential rotation
- RBAC grants minimal required permissions
- TLS termination at Traefik (Let's Encrypt)
- No public exposure of Redis or PostgreSQL
- Security headers on frontend (CSP, X-Frame-Options, etc.)
- CORS properly configured for API
- Rate limiting on API endpoints (100 req/min average, 50 burst)

### Deployment Architecture

```
Internet (HTTPS)
    ↓
Traefik (Let's Encrypt TLS)
    ↓
    ├─→ moltbook.ardenone.com → Frontend (Next.js, 2 replicas)
    │       └─ Security Headers Middleware
    │
    └─→ api-moltbook.ardenone.com → API (Node.js, 2 replicas)
            ├─ CORS Middleware
            ├─ Rate Limiting Middleware (100/min)
            ↓
            ├─→ PostgreSQL (CNPG, 1 instance, 10Gi)
            └─→ Redis (1 replica, cache only)
```

---

## Related Beads

### Active Beads
- **mo-saz** (this bead): Implementation: Deploy Moltbook platform to ardenone-cluster ⏳ IN PROGRESS
- **mo-382** (Priority 0): Fix: Apply RBAC for Moltbook deployment - namespace creation blocked 🆕 CONSOLIDATED BLOCKER

### Superseded Beads (Close after mo-382 is resolved)
The following P0 beads are now superseded by mo-382:
- mo-hfs, mo-3rs, mo-3uo, mo-32c, mo-drj, mo-hv4, mo-3iz, mo-2fr, mo-bai, mo-272

## Critical Deployment Blockers (2026-02-04)

### 1. Namespace Creation Requires Cluster Admin (BLOCKER)
**Status:** The devpod ServiceAccount lacks permission to create namespaces

**Error:** `namespaces is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "namespaces"`

**Resolution:**
- Cluster admin must apply: `kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml`
- See `k8s/DEPLOYMENT_BLOCKER.md` for complete details

**New Blocker Bead:** mo-382 consolidates all namespace creation blocker beads

### 2. ArgoCD Not Operational (INFO)
**Status:** ArgoCD namespace exists but no controller/server pods are running

**Impact:** GitOps deployment via ArgoCD is not available. The ArgoCD Application manifest (`k8s/argocd-application.yml`) cannot be used.

**Verification:**
```bash
kubectl get pods -n argocd  # Returns "No resources found in argocd namespace"
```

**Resolution Options:**
1. Install/reinstall ArgoCD in the cluster before using GitOps deployment
2. Deploy directly using `kubectl apply -k k8s/` instead of ArgoCD (RECOMMENDED for current state)

### Test Results Summary
- ✅ **API Tests:** 14/14 passing (Auth Utils, Error Classes, Config)
- ✅ **Frontend Tests:** 36/36 passing (Components, Utils)
- ✅ **Manifests Validated:** All YAML manifests syntactically correct
- ✅ **Kustomization Builds:** 1050 lines generated successfully
