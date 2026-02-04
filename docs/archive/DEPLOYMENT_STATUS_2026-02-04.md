# Moltbook Platform Deployment Status
**Date**: 2026-02-04
**Bead**: mo-saz
**Target**: ardenone-cluster

## Summary

Kubernetes manifests are fully configured and ready for deployment. The backend API container image has been successfully built. Deployment is currently blocked by two issues requiring resolution.

## Infrastructure Components Ready ✅

### 1. Kubernetes Manifests (Complete)
All infrastructure manifests have been created and validated:

- **Namespace**: `k8s/namespace/moltbook-namespace.yml`
- **RBAC**: `k8s/namespace/moltbook-rbac.yml`
- **Database (CNPG)**: `k8s/database/cluster.yml`
  - PostgreSQL 15 with CloudNativePG
  - 10Gi storage, single instance
  - Schema initialization via ConfigMap
- **Redis**: `k8s/redis/` (optional caching layer)
- **API Backend**: `k8s/api/`
  - Deployment with 2 replicas
  - Health checks and resource limits
  - ConfigMap and SealedSecrets
- **Frontend**: `k8s/frontend/`
  - Deployment with 2 replicas
  - Next.js standalone build
- **IngressRoutes**: Traefik with TLS
  - `moltbook.ardenone.com` → Frontend
  - `api-moltbook.ardenone.com` → Backend API
  - CORS middleware for API
  - Security headers for frontend

### 2. Container Images

**API**: ✅ Built and pushed
- Image: `ghcr.io/ardenone/moltbook-api:latest`
- Status: Successfully built in GitHub Actions (run #21680085939)
- Node.js 18 Alpine with multi-stage build

**Frontend**: ❌ Build failed
- Image: `ghcr.io/ardenone/moltbook-frontend:latest`
- Status: TypeScript compilation error
- Issue tracked in bead **mo-wm2**

### 3. Secrets Management

SealedSecrets created and ready:
- `moltbook-api-secrets` (DATABASE_URL, JWT_SECRET, Twitter OAuth)
- `moltbook-postgres-superuser` (PostgreSQL admin credentials)
- `moltbook-db-credentials` (App database credentials)

### 4. GitOps Configuration

ArgoCD Application manifest ready:
- Path: `k8s/argocd-application.yml`
- Automated sync with prune and self-heal
- CreateNamespace sync option enabled

## Blockers 🚨

### Blocker 1: Namespace Creation Permission
**Bead**: mo-3iz (Priority 0 - Critical)

**Issue**: Current ServiceAccount (`devpod:default`) lacks cluster-scoped permissions to create namespaces.

**Error**:
```
namespaces is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
```

**Resolution Required**:
```bash
# Cluster admin must run:
kubectl create namespace moltbook
```

**Workaround**: Use `kustomization-no-namespace.yml` which excludes namespace creation

### Blocker 2: Frontend TypeScript Build Error
**Bead**: mo-wm2 (Priority 0 - Critical)

**Issue**: Frontend build fails with module export error:
```
Type error: Module '@/components/ui' has no exported member 'Popover'
```

**Investigation Needed**:
- Component IS exported in `src/components/ui/index.tsx:300`
- Possible TypeScript cache or configuration issue
- API built successfully, only frontend affected

## Deployment Strategy

### Option 1: Full GitOps (Recommended)
1. Resolve blockers (namespace + frontend build)
2. Deploy ArgoCD Application:
   ```bash
   kubectl apply -f k8s/argocd-application.yml
   ```
3. ArgoCD automatically syncs and deploys all components

### Option 2: Manual Kubectl (Workaround)
1. Have cluster admin create namespace:
   ```bash
   kubectl create namespace moltbook
   ```
2. Deploy backend only (API works):
   ```bash
   cd k8s
   kubectl apply -k . -n moltbook
   # Skip frontend resources until mo-wm2 resolved
   ```

## Next Steps

### Immediate
1. **[Critical]** Create `moltbook` namespace (requires cluster admin)
2. **[Critical]** Fix frontend TypeScript build error (bead mo-wm2)
3. Test API deployment once namespace exists

### Post-Blockers
1. Deploy via ArgoCD or kubectl kustomize
2. Verify PostgreSQL cluster creation and initialization
3. Verify API pods start and pass health checks
4. Test API endpoints: `https://api-moltbook.ardenone.com/health`
5. Deploy frontend once build fixed
6. Test full stack integration

## Architecture

```
┌─────────────────────────────────────────┐
│         ardenone-cluster                │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────┐  ┌────────────────┐ │
│  │   Traefik     │  │  External DNS  │ │
│  │  IngressRoute │  │  (Cloudflare)  │ │
│  └───────┬───────┘  └────────────────┘ │
│          │                              │
│  ┌───────┴──────────────────────┐      │
│  │    moltbook namespace        │      │
│  │                              │      │
│  │  Frontend (pending)          │      │
│  │  └─ Next.js (build blocked)  │      │
│  │                              │      │
│  │  Backend API (ready)         │      │
│  │  └─ Node.js Express          │      │
│  │     └─ ghcr.io/.../api:latest│      │
│  │                              │      │
│  │  PostgreSQL (CNPG)           │      │
│  │  └─ 10Gi PVC                 │      │
│  │  └─ Schema initialized       │      │
│  │                              │      │
│  │  Redis (optional)            │      │
│  │  └─ Caching layer            │      │
│  │                              │      │
│  │  SealedSecrets               │      │
│  │  └─ DB credentials           │      │
│  │  └─ JWT secret               │      │
│  └──────────────────────────────┘      │
└─────────────────────────────────────────┘
```

## Domain Configuration

Domains are managed by ExternalDNS + Cloudflare (no nested subdomains):
- ✅ `moltbook.ardenone.com` - Frontend
- ✅ `api-moltbook.ardenone.com` - Backend API

## Repository

- **GitHub**: https://github.com/ardenone/moltbook-org
- **Branch**: main
- **K8s Manifests**: `/k8s`
- **CI/CD**: `.github/workflows/build-push.yml`

## Related Beads

- **mo-wm2**: Fix frontend TypeScript build error (Priority 0)
- **mo-3iz**: Create moltbook namespace (Priority 0)
- **mo-saz**: Main implementation bead (this deployment)

## Deployment Readiness: 75%

| Component | Status | Notes |
|-----------|--------|-------|
| Manifests | ✅ 100% | All files validated |
| API Image | ✅ Built | ghcr.io/ardenone/moltbook-api:latest |
| Frontend Image | ❌ Failed | TypeScript build error |
| Namespace | ❌ Blocked | Need admin permissions |
| Secrets | ✅ Ready | SealedSecrets created |
| Database | ✅ Ready | CNPG manifest ready |
| IngressRoutes | ✅ Ready | Traefik configured |
| ArgoCD | ✅ Ready | Application manifest ready |

**Conclusion**: Infrastructure is deployment-ready. Two critical blockers (namespace creation + frontend build) must be resolved before production deployment. Backend API can be deployed independently once namespace exists.
