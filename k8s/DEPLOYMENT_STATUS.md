# Moltbook Deployment Status - ardenone-cluster

**Last Updated**: 2026-02-04 17:30 UTC
**Bead**: mo-saz
**Task**: Implementation: Deploy Moltbook platform to ardenone-cluster

---

## Summary

| Component | Status | Notes |
|-----------|--------|-------|
| API Backend | ⚠️ Partial | Container image builds successfully in GHCR |
| Frontend | ❌ Blocked | React context build error (bead mo-3d00) |
| Database (PostgreSQL) | ✅ Ready | CloudNativePG manifests ready |
| Redis | ✅ Ready | Deployment manifests ready |
| Kubernetes Manifests | ✅ Ready | All K8s manifests in k8s/ directory |
| RBAC | ❌ Blocked | Namespace creation requires cluster admin |

---

## Container Images

### API Backend
- **Image**: `ghcr.io/ardenone/moltbook-api:latest`
- **Status**: ✅ Builds successfully in GitHub Actions CI/CD
- **Digest**: Available in GHCR (build: 220d9302)

### Frontend
- **Image**: `ghcr.io/ardenone/moltbook-frontend:latest`
- **Status**: ❌ Build failing
- **Error**: `TypeError: (0 , n.createContext) is not a function`
- **Blocker Bead**: mo-3d00

---

## Deployment Blockers

### 1. RBAC Permissions (Priority: HIGH)
- **Issue**: `devpod` ServiceAccount lacks namespace creation permission
- **Required Action**: Cluster admin must apply:
  ```bash
  kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
  ```
- **Manifest Location**: `k8s/namespace/devpod-namespace-creator-rbac.yml`

### 2. Frontend Build Error (Priority: MEDIUM)
- **Issue**: React context error during Next.js build
- **Error Details**:
  ```
  TypeError: (0 , n.createContext) is not a function
  at chunk during "Collecting page data" phase
  ```
- **Affects**: Pages using React Context (notifications, not-found)
- **Root Cause**: Next.js 14 SSR + Radix UI compatibility
- **Blocker Bead**: mo-3d00

---

## Next Steps

### Once RBAC is Granted:

1. **Create Namespace**:
   ```bash
   kubectl create namespace moltbook
   ```

2. **Deploy Database**:
   ```bash
   kubectl apply -f k8s/database/
   ```

3. **Deploy Redis**:
   ```bash
   kubectl apply -f k8s/redis/
   ```

4. **Deploy API** (using existing image):
   ```bash
   kubectl apply -f k8s/api/
   ```

5. **Deploy Frontend** (blocked on mo-3d00):
   ```bash
   # Once frontend image is built:
   kubectl apply -f k8s/frontend/
   ```

---

## ArgoCD Integration

- **Application Manifest**: `k8s/argocd-application.yml`
- **Target Namespace**: `moltbook`
- **Sync Policy**: Automated
- **Status**: ⚠️ Namespace does not exist yet

---

## Related Beads

- **mo-saz**: This deployment task
- **mo-3d00**: Frontend React context build error
- **mo-jgo**: Docker build issues in devpod environment

---

## Notes

- All Kubernetes manifests are production-ready
- Database schema is pre-configured in ConfigMap
- SealedSecrets are pre-generated for production
- IngressRoutes configured for:
  - `moltbook.ardenone.com` (frontend)
  - `api-moltbook.ardenone.com` (API)
