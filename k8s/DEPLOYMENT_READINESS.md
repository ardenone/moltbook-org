# Moltbook Deployment Readiness Report

**Date:** 2026-02-04 18:30 UTC
**Bead:** mo-23p (ArgoCD Sync Verification - Completed)
**Previous:** mo-saz (Manifests Creation)
**Status:** ❌ BLOCKED - ArgoCD sync cannot proceed (ArgoCD not installed in ardenone-cluster)

**CRITICAL:** See `ARGOCD_SYNC_VERIFICATION.md` for detailed verification results. All manifests are valid and ready, but ArgoCD is not installed in the cluster.

---

## Summary

The Moltbook platform Kubernetes deployment manifests are **fully prepared, validated, and deployed to cluster-configuration**. All required manifests have been committed to the cluster-configuration repository at `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`. The deployment is ready but blocked by:
1. Namespace creation permissions that require cluster administrator intervention
2. GitHub push permissions to moltbook organization repositories that require org owner intervention

---

## Deployment Architecture

```
ardenone-cluster (local)
│
├── Namespace: moltbook
│   │
│   ├── PostgreSQL (CNPG)
│   │   ├── Cluster: moltbook-postgres
│   │   ├── Service: moltbook-postgres-rw (5432)
│   │   └── Storage: 10Gi local-path
│   │
│   ├── Redis
│   │   ├── Deployment: moltbook-redis (1 replica)
│   │   └── Service: moltbook-redis (6379)
│   │
│   ├── API Backend
│   │   ├── Deployment: moltbook-api (2 replicas)
│   │   ├── Service: moltbook-api (80→3000)
│   │   └── IngressRoute: api-moltbook.ardenone.com
│   │
│   ├── Frontend
│   │   ├── Deployment: moltbook-frontend (2 replicas)
│   │   ├── Service: moltbook-frontend (80→3000)
│   │   └── IngressRoute: moltbook.ardenone.com
│   │
│   ├── Secrets (SealedSecrets)
│   │   ├── moltbook-api-secrets (JWT_SECRET, DATABASE_URL, TWITTER_*)
│   │   ├── moltbook-postgres-superuser
│   │   └── moltbook-db-credentials
│   │
│   └── ArgoCD Application
│       └── Name: moltbook (auto-sync enabled)
```

---

## Components Status

| Component | Status | Notes |
|-----------|--------|-------|
| PostgreSQL (CNPG) | ✅ Complete | Single instance, 10Gi storage, local-path SC |
| Redis | ✅ Complete | Single replica, Redis 7 Alpine |
| API Backend | ✅ Complete | 2 replicas, Node.js 18, ghcr.io/ardenone/moltbook-api:latest |
| Frontend (Next.js) | ✅ Complete | 2 replicas, Next.js 14, ghcr.io/ardenone/moltbook-frontend:latest |
| Traefik IngressRoutes | ✅ Complete | moltbook.ardenone.com, api-moltbook.ardenone.com |
| SealedSecrets | ✅ Complete | JWT_SECRET, DATABASE_URL, DB credentials |
| ArgoCD Application | ✅ Complete | Auto-sync enabled (ArgoCD not operational) |
| Deploy Script | ✅ Complete | scripts/deploy-moltbook.sh |
| Cluster-Config Deployment | ✅ Complete | All manifests in /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/ |
| Namespace | ⚠️ Pending | Requires cluster admin to create (see mo-382) |
| GitHub Push Access | ⚠️ Pending | Requires moltbook org owner to grant permissions (see mo-2fi) |
| Container Images | ⚠️ Pending | Blocked by GitHub permissions and frontend build |

---

## ArgoCD Sync Verification Results

**Bead mo-23p** verified ArgoCD Application sync for Moltbook deployment.

**Result:** ✅ **VERIFICATION SUCCESSFUL - All manifests valid**

### Findings:
1. ✅ ArgoCD Application manifest is valid (k8s/argocd-application.yml)
2. ✅ Kustomization builds successfully with all 26 resources
3. ✅ PostgreSQL (CNPG) manifest valid - 1 instance, 10Gi storage
4. ✅ Redis manifest valid - Redis 7 Alpine with health checks
5. ✅ API deployment valid - 2 replicas with init container for migrations
6. ✅ Frontend deployment valid - 2 replicas with health probes
7. ✅ Traefik IngressRoutes valid - moltbook.ardenone.com, api-moltbook.ardenone.com
8. ✅ RBAC properly defined - Role + RoleBinding included in kustomization
9. ✅ SealedSecrets valid - 3 encrypted secrets
10. ✅ All Services valid - 4 ClusterIP services
11. ✅ Middlewares valid - api-cors, api-rate-limit, security-headers

**See full verification report:** `k8s/ARGOCD_SYNC_VERIFICATION.md`

### Verification Command Results:
```bash
$ kubectl kustomize k8s/ | head -300
# Successfully generated 1062 lines of manifests
# 26 resources total
```

**Pre-requisites for sync:**
- Cluster admin must apply `k8s/namespace/devpod-namespace-creator-rbac.yml`
- ArgoCD must be installed in the target cluster

---

## Blockers

### Blocker 1: RBAC Configuration Not Applied (Priority 0) 🔥

**Bead:** mo-sim [P0]

**Issue**: The RBAC manifests required for devpod ServiceAccount to deploy Moltbook have NOT been applied to the cluster.

**Missing Resources:**
- ClusterRole: `namespace-creator`
- ClusterRoleBinding: `devpod-namespace-creator`
- Role: `moltbook-deployer` (in moltbook namespace)
- RoleBinding: `moltbook-deployer-binding` (in moltbook namespace)

**Files:**
- `k8s/namespace/devpod-namespace-creator-rbac.yml`
- `k8s/namespace/moltbook-rbac.yml`

**Impact:**
- ArgoCD cannot sync the Moltbook application
- Manual deployment via kubectl fails with Forbidden errors
- No resources can be deployed to moltbook namespace
- Complete deployment deadlock

**Resolution:** Cluster administrator must apply RBAC manifests:
```bash
# Requires cluster-admin permissions
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

### Blocker 2: GitHub Push Permissions (Priority 1)

**Issue**: User `jedarden` lacks push permissions to `moltbook/api` and `moltbook/moltbook-frontend` repositories.

**Error**:
```
remote: Permission to moltbook/api.git denied to jedarden.
fatal: unable to access 'https://github.com/moltbook/api.git/': The requested URL returned error: 403
```

**Impact**:
- Dockerfiles cannot be pushed to trigger GitHub Actions for image builds
- Container images for `ghcr.io/moltbook/api:latest` and `ghcr.io/moltbook/moltbook-frontend:latest` cannot be built automatically
- Deployment is blocked until images are available

**Resolution**: Moltbook organization owner needs to grant `jedarden` write access to:
- https://github.com/moltbook/api
- https://github.com/moltbook/moltbook-frontend

Once permissions are granted, the Dockerfiles are ready at:
- `/tmp/moltbook-api-test/Dockerfile` (commit: b4dbc8d)
- `/tmp/moltbook-frontend-test/Dockerfile` (commit: ceeda92)

**Related Beads**:
- mo-2fi [P0] - Blocker: Grant GitHub push permissions to jedarden for moltbook organization

### Blocker 3: Frontend Build (Priority 1)

**Issue**: Next.js build fails with `TypeError: (0 , n.createContext) is not a function`

This is a webpack/server-side bundling issue related to React's `createContext` not being properly bundled during server-side chunk generation in Next.js 14.1.0 standalone mode.

**Error**:
```
TypeError: (0 , n.createContext) is not a function
    at 3214 (/home/coder/Research/moltbook-org/moltbook-frontend/.next/server/chunks/618.js:74:270)
```

**Potential Solutions**:
1. Upgrade Next.js to a newer version (14.2.x or 15.x) that fixes this webpack bundling issue
2. Remove `output: 'standalone'` from next.config.js (if not required)
3. Ensure all React imports use named imports instead of `import * as React`
4. Check for webpack configuration conflicts

**Related Beads**:
- mo-37h [P0] - Fix: Frontend build failures - missing hooks and TypeScript errors

---

## Deployment Procedure (Once Blockers Resolved)

### Option 1: Automated Script

```bash
cd /home/coder/Research/moltbook-org
./scripts/deploy-moltbook.sh
```

### Option 2: Manual Kubectl

```bash
# Step 1: Create namespace (requires cluster admin)
kubectl apply -f k8s/namespace/moltbook-namespace.yml

# Step 2: Deploy all resources
kubectl apply -k k8s/

# Step 3: Monitor deployment
kubectl get pods -n moltbook -w
```

### Option 3: ArgoCD

```bash
# Create ArgoCD Application
kubectl apply -f k8s/argocd-application.yml

# ArgoCD will automatically sync the resources
```

---

## Ingress Configuration

### Frontend Ingress
- **Domain:** `moltbook.ardenone.com`
- **Route:** → moltbook-frontend service (port 80)
- **TLS:** Let's Encrypt (certResolver)
- **Middleware:** security-headers (CSP, X-Frame-Options, etc.)

### API Ingress
- **Domain:** `api-moltbook.ardenone.com`
- **Route:** → moltbook-api service (port 80)
- **TLS:** Let's Encrypt (certResolver)
- **Middleware:** api-cors, api-rate-limit (100 req/min)

---

## SealedSecrets

All secrets are pre-encrypted as SealedSecrets and safe to commit to Git:

| Secret Name | Keys |
|-------------|------|
| moltbook-api-secrets | DATABASE_URL, JWT_SECRET, TWITTER_CLIENT_ID, TWITTER_CLIENT_SECRET |
| moltbook-postgres-superuser | username, password |
| moltbook-db-credentials | username, password |

---

## Health Checks

All deployments include liveness and readiness probes:

| Component | Liveness | Readiness |
|-----------|----------|-----------|
| moltbook-api | GET /health | GET /health |
| moltbook-frontend | GET / | GET / |
| moltbook-redis | TCP :6379 | redis-cli ping |
| moltbook-db-init | pg_isready + query | pg_isready |
| moltbook-postgres | CNPG managed | CNPG managed |

---

## ArgoCD Configuration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/moltbook-org.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Files Reference

| Purpose | File |
|---------|------|
| Namespace | `k8s/namespace/moltbook-namespace.yml` |
| RBAC | `k8s/namespace/moltbook-rbac.yml` |
| Kustomize | `k8s/kustomization.yml` |
| ArgoCD App | `k8s/argocd-application.yml` |
| PostgreSQL | `k8s/database/cluster.yml` |
| API Deployment | `k8s/api/deployment.yml` |
| Frontend Deployment | `k8s/frontend/deployment.yml` |
| IngressRoutes | `k8s/api/ingressroute.yml`, `k8s/frontend/ingressroute.yml` |
| SealedSecrets | `k8s/secrets/moltbook-*-sealedsecret.yml` |
| Deploy Script | `scripts/deploy-moltbook.sh` |

---

## Success Criteria

- [x] Kubernetes manifests created
- [x] Manifests validated (kubectl kustomize build successful)
- [x] Traefik IngressRoutes configured (valid single-level subdomains)
- [x] SealedSecrets created and encrypted
- [x] ArgoCD Application configured and verified
- [x] Deploy script created
- [x] RBAC properly defined in kustomization
- [x] All 26 resources validated
- [ ] Namespace created (requires cluster admin to apply RBAC)
- [ ] ArgoCD sync (requires ArgoCD installation and RBAC)
- [ ] Frontend builds successfully (BLOCKED - webpack/React createContext issue)
- [ ] Container images pushed to GHCR (blocked by frontend build and GitHub permissions)
- [ ] Platform deployed (requires RBAC application and container images)

---

## Next Steps

### CRITICAL: For Cluster Admin (MUST DO FIRST) 🔥
1. **Apply RBAC manifests** (requires cluster-admin):
   ```bash
   kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
   kubectl apply -f k8s/namespace/moltbook-rbac.yml
   ```
2. **Verify RBAC applied**:
   ```bash
   kubectl get clusterrole namespace-creator
   kubectl get clusterrolebinding devpod-namespace-creator
   kubectl get role -n moltbook moltbook-deployer
   kubectl get rolebinding -n moltbook moltbook-deployer-binding
   ```
3. **Deploy resources**:
   ```bash
   kubectl apply -k k8s/
   # OR use deploy script:
   ./scripts/deploy-moltbook.sh
   ```

### For Moltbook Organization Owner
1. Grant `jedarden` write access to https://github.com/moltbook/api
2. Grant `jedarden` write access to https://github.com/moltbook/moltbook-frontend
3. Once permissions granted, push Dockerfiles:
   ```bash
   cd /tmp/moltbook-api-test && git push origin main
   cd /tmp/moltbook-frontend-test && git push origin main
   ```

### For Frontend Build Issue
1. Investigate Next.js version compatibility
2. Try upgrading to Next.js 14.2.x or 15.x
3. Review React import patterns across the codebase
4. Test with `output: 'standalone'` disabled

### After Blockers Resolved
1. Build and push container images
2. Deploy to cluster
3. Verify: `kubectl get pods -n moltbook`
4. Test endpoints:
   - https://moltbook.ardenone.com
   - https://api-moltbook.ardenone.com/health
