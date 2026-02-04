# Moltbook Deployment Readiness Report

**Date:** 2026-02-04 18:30 UTC
**Bead:** mo-saz
**Status:** Manifests Complete - All changes committed, awaiting cluster admin for namespace creation

---

## Summary

The Moltbook platform Kubernetes deployment manifests are **fully prepared, validated, and deployed to cluster-configuration**. All required manifests have been committed to the cluster-configuration repository at `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`. The deployment is ready but blocked by namespace creation permissions that require cluster administrator intervention.

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
| Container Images | ⚠️ Pending | Requires frontend build fix |

---

## Blockers

### Blocker 1: Namespace Creation (Priority 0)

**Issue**: ServiceAccount lacks permissions to create namespaces.

**Error**:
```
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
```

**Resolution**: Cluster admin needs to run:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-namespace.yml
```

Or use the deploy script:
```bash
./scripts/deploy-moltbook.sh
```

### Blocker 2: Frontend Build (Priority 0)

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
- [x] Manifests validated
- [x] Traefik IngressRoutes configured
- [x] SealedSecrets created
- [x] ArgoCD Application configured
- [x] Deploy script created
- [ ] Namespace created (BLOCKED - requires cluster admin)
- [ ] Frontend builds successfully (BLOCKED - webpack/React createContext issue)
- [ ] Container images pushed to GHCR (blocked by frontend build)
- [ ] Platform deployed (blocked by above issues)

---

## Next Steps

### For Cluster Admin
1. **Create namespace**: `kubectl apply -f k8s/namespace/moltbook-namespace.yml`
2. **Or run deploy script**: `./scripts/deploy-moltbook.sh`

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
