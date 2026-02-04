# Moltbook Deployment Blocker Analysis

**Date:** 2026-02-04
**Task:** mo-saz - Deploy Moltbook platform to ardenone-cluster
**Status:** BLOCKED - Critical blockers require external intervention

---

## Executive Summary

The Moltbook platform deployment to ardenone-cluster is **fully prepared but blocked** by three critical issues that require intervention from cluster administrators and Moltbook organization owners.

**Status:**
- Kubernetes manifests: 100% complete
- SealedSecrets: 100% complete
- ArgoCD configuration: 100% complete
- Cluster deployment: 0% - BLOCKED by RBAC

---

## Blocker Summary

| Priority | Blocker | Owner | Status | Bead |
|----------|---------|-------|--------|------|
| P0 | RBAC permissions not applied | Cluster Admin | Not Applied | mo-18q |
| P1 | Frontend build failure | Development Team | Failed | mo-15b8 |
| P1 | GitHub push permissions | Moltbook Org Owner | Not Granted | mo-2iqc |

---

## Blocker 1: RBAC Permissions Not Applied (P0) CRITICAL

### Issue
The devpod ServiceAccount lacks permissions to:
1. Create the `moltbook` namespace
2. Create ClusterRole/ClusterRoleBinding resources
3. Deploy resources to the moltbook namespace

### Verification
```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl auth can-i create namespace
no

$ kubectl auth can-i create clusterrole
no

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles "namespace-creator" not found
```

### Required Actions (Cluster Administrator)

**Step 1:** Apply the namespace-creator ClusterRole:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- `ClusterRole: namespace-creator` - grants namespace creation permissions
- `ClusterRoleBinding: devpod-namespace-creator` - binds to devpod ServiceAccount

**Step 2:** Apply the namespace manifest:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-namespace.yml
```

**Step 3:** Apply the moltbook RBAC:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-rbac.yml
```

This creates:
- `Role: moltbook-deployer` - grants deployment permissions in moltbook namespace
- `RoleBinding: moltbook-deployer-binding` - binds to devpod ServiceAccount

**Step 4:** Verify permissions:
```bash
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
kubectl get namespace moltbook
kubectl get role -n moltbook moltbook-deployer
```

### Impact
- Complete deployment deadlock
- No resources can be deployed
- ArgoCD cannot sync the application

---

## Blocker 2: Frontend Build Failure (P1)

### Issue
Next.js build fails during standalone build process:
```
TypeError: (0 , n.createContext) is not a function
    at 3214 (/home/coder/Research/moltbook-org/moltbook-frontend/.next/server/chunks/618.js:74:270)
```

### Root Cause Analysis
This is a webpack bundling issue related to React's `createContext` not being properly bundled during server-side chunk generation in Next.js 14.1.0 standalone mode.

### Potential Solutions
1. **Upgrade Next.js**: Upgrade to 14.2.x or 15.x which includes webpack bundling fixes
2. **Remove standalone output**: Disable `output: 'standalone'` in next.config.js if not required
3. **Review React imports**: Ensure all React imports use named imports instead of `import * as React`
4. **Check webpack config**: Review for webpack configuration conflicts

### Required Actions
1. Investigate Next.js version compatibility with standalone mode
2. Test build with upgraded Next.js version
3. Fix any React import issues found in codebase
4. Verify standalone output configuration

### Impact
- Container image `ghcr.io/ardenone/moltbook-frontend:latest` cannot be built
- Frontend deployment is blocked until image is available

---

## Blocker 3: GitHub Push Permissions (P1)

### Issue
User `jedarden` lacks push permissions to moltbook organization repositories.

### Error
```
remote: Permission to moltbook/api.git denied to jedarden.
fatal: unable to access 'https://github.com/moltbook/api.git/': The requested URL returned error: 403
```

### Affected Repositories
- https://github.com/moltbook/api
- https://github.com/moltbook/moltbook-frontend

### Required Actions (Moltbook Organization Owner)
1. Grant `jedarden` write access to `moltbook/api` repository
2. Grant `jedarden` write access to `moltbook/moltbook-frontend` repository
3. Once permissions are granted, push Dockerfiles to trigger GitHub Actions builds

### Ready-to-Push Dockerfiles
- `/home/coder/Research/moltbook-org/api/Dockerfile`
- `/home/coder/Research/moltbook-org/moltbook-frontend/Dockerfile`

### Impact
- Cannot push Dockerfiles to trigger automated container image builds
- Container images must be available at:
  - `ghcr.io/ardenone/moltbook-api:latest`
  - `ghcr.io/ardenone/moltbook-frontend:latest`

---

## Deployment Architecture

### Planned Deployment Structure
```
ardenone-cluster
│
└── Namespace: moltbook
    │
    ├── PostgreSQL (CNPG)
    │   ├── Cluster: moltbook-postgres
    │   ├── Service: moltbook-postgres-rw (5432)
    │   └── Storage: 10Gi local-path
    │
    ├── Redis
    │   ├── Deployment: moltbook-redis (1 replica)
    │   └── Service: moltbook-redis (6379)
    │
    ├── API Backend
    │   ├── Deployment: moltbook-api (2 replicas)
    │   ├── Service: moltbook-api (80→3000)
    │   └── IngressRoute: api-moltbook.ardenone.com
    │
    ├── Frontend
    │   ├── Deployment: moltbook-frontend (2 replicas)
    │   ├── Service: moltbook-frontend (80→3000)
    │   └── IngressRoute: moltbook.ardenone.com
    │
    ├── Secrets (SealedSecrets)
    │   ├── moltbook-api-secrets (JWT_SECRET, DATABASE_URL, TWITTER_*)
    │   ├── moltbook-postgres-superuser
    │   └── moltbook-db-credentials
    │
    └── ArgoCD Application
        └── Name: moltbook (auto-sync enabled)
```

---

## ArgoCD Configuration

The ArgoCD Application is configured but cannot sync due to missing namespace:

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
    kustomize:
      images:
        - ghcr.io/ardenone/moltbook-api:latest
        - ghcr.io/ardenone/moltbook-frontend:latest
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
```

---

## Ingress Configuration

### Frontend
- **Domain:** `moltbook.ardenone.com`
- **Route:** → moltbook-frontend service (port 80)
- **TLS:** Let's Encrypt (certResolver)
- **Middleware:** security-headers (CSP, X-Frame-Options, etc.)

### API
- **Domain:** `api-moltbook.ardenone.com`
- **Route:** → moltbook-api service (port 80)
- **TLS:** Let's Encrypt (certResolver)
- **Middleware:** api-cors, api-rate-limit (100 req/min)

---

## Deployment Procedure (Once Blockers Resolved)

### Option 1: Automated Script
```bash
cd /home/coder/Research/moltbook-org
./scripts/deploy-moltbook.sh
```

### Option 2: Manual Kubectl
```bash
# Step 1: Deploy all resources
kubectl apply -k /home/coder/Research/moltbook-org/k8s/

# Step 2: Monitor deployment
kubectl get pods -n moltbook -w
```

### Option 3: ArgoCD
```bash
# Create ArgoCD Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# ArgoCD will automatically sync the resources
```

---

## Success Criteria

| Criterion | Status | Notes |
|-----------|--------|-------|
| Kubernetes manifests created | ✅ Complete | All manifests valid and ready |
| Traefik IngressRoutes configured | ✅ Complete | Both frontend and API |
| SealedSecrets created | ✅ Complete | All secrets encrypted |
| ArgoCD Application configured | ✅ Complete | Auto-sync enabled |
| RBAC permissions applied | ❌ BLOCKED | Requires cluster admin |
| Frontend builds successfully | ❌ BLOCKED | webpack/createContext issue |
| Container images pushed to GHCR | ❌ BLOCKED | Requires GitHub permissions |
| Platform deployed | ❌ BLOCKED | Waiting for above issues |

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-18q | Blocker: Apply RBAC manifests for Moltbook deployment | 0 | Created |
| mo-15b8 | Fix: Frontend build failure - createContext error | 1 | Created |
| mo-2iqc | Blocker: Grant GitHub push permissions for container image builds | 1 | Created |

---

## Next Steps

### Immediate (Requires Cluster Admin) 🔥
1. Apply RBAC manifests:
   ```bash
   kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
   kubectl apply -f k8s/namespace/moltbook-namespace.yml
   kubectl apply -f k8s/namespace/moltbook-rbac.yml
   ```

### Short Term (Requires Moltbook Org Owner)
1. Grant GitHub write permissions to `jedarden`
2. Push Dockerfiles to trigger builds

### Short Term (Development Team)
1. Fix Next.js build issue
2. Build and push container images
3. Verify deployment

### After Blockers Resolved
1. Deploy all resources: `kubectl apply -k k8s/`
2. Verify: `kubectl get pods -n moltbook`
3. Test endpoints:
   - https://moltbook.ardenone.com
   - https://api-moltbook.ardenone.com/health

---

## Conclusion

The Moltbook deployment is **100% prepared from a manifest perspective** but **completely blocked from an operational perspective**. The primary blocker (P0 - RBAC) requires cluster administrator intervention to create the namespace and apply RBAC policies. Secondary blockers (P1) involve frontend build issues and GitHub permissions that must be resolved before container images can be built and deployed.

Once all blockers are resolved, the deployment should proceed smoothly via kubectl or ArgoCD using the existing, validated manifests.
