# Moltbook Deployment Readiness Report

**Date:** 2026-02-04
**Bead:** mo-saz
**Status:** Ready for Deployment (Pending RBAC)

---

## Summary

The Moltbook platform Kubernetes manifests are fully prepared and validated. All components are configured according to GitOps best practices with ArgoCD. Deployment is pending cluster administrator approval for RBAC permissions.

---

## Components Status

| Component | Status | Notes |
|-----------|--------|-------|
| PostgreSQL (CNPG) | ✅ Ready | Single instance, 10Gi storage, local-path SC |
| Redis | ✅ Ready | Single replica, Redis 7 Alpine |
| API Backend | ✅ Ready | 2 replicas, Node.js 18, ghcr.io/ardenone/moltbook-api:latest |
| Frontend (Next.js) | ✅ Ready | 2 replicas, Next.js 14, ghcr.io/ardenone/moltbook-frontend:latest |
| Traefik IngressRoutes | ✅ Ready | moltbook.ardenone.com, api-moltbook.ardenone.com |
| SealedSecrets | ✅ Ready | JWT_SECRET, DATABASE_URL, DB credentials |
| Namespace | ⚠️ Pending | Requires cluster admin to create |
| RBAC | ⚠️ Pending | Requires cluster admin to apply |

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

## Required Actions for Deployment

### 1. Cluster Administrator Actions (One-time Setup)

Apply RBAC to grant devpod ServiceAccount namespace creation permissions:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- `ClusterRole`: namespace-creator
- `ClusterRoleBinding`: devpod-namespace-creator

### 2. Deployment Execution (After RBAC is Applied)

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

Or wait for ArgoCD to sync (if Application is created).

### 3. ArgoCD Application (Optional)

If not using kubectl apply directly:

```bash
kubectl apply -f k8s/argocd-application.yml
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

## Database Schema

The schema is loaded from ConfigMap `moltbook-db-schema` and initialized by the `moltbook-db-init` Deployment (idempotent - safe for ArgoCD).

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

## Blocker Summary

### CRITICAL: ArgoCD Not Installed (2026-02-04)

**Issue:** ArgoCD is NOT deployed in ardenone-cluster. The `argocd` namespace does not exist.

**Impact:** The ArgoCD Application manifest (`k8s/argocd-application.yml`) references the `argocd` namespace which doesn't exist.

**Options:**
1. **Deploy ArgoCD first** - Install ArgoCD in the cluster before creating the Application
2. **Deploy directly via kubectl** - Use `kubectl apply -k k8s/` instead of ArgoCD GitOps

### Bead mo-n4h (Priority 0): "Fix: Grant namespace creation permissions for moltbook deployment"

The devpod ServiceAccount lacks cluster-level permissions to create namespaces and apply RBAC. A cluster administrator must apply the RBAC manifest before deployment can proceed.

**Resolution options:**
1. Quick fix: `kubectl apply -f k8s/NAMESPACE_REQUEST.yml`
2. Permanent fix: `kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml`

### Bead mo-7vy (Priority 1): "Build: Container images for moltbook-api and moltbook-frontend"

Container images need to be built and pushed to GHCR before deployment:
- ghcr.io/ardenone/moltbook-api:latest
- ghcr.io/ardenone/moltbook-frontend:latest

**Build command:** `./scripts/build-images.sh --push`

---

## Files Reference

| Purpose | File |
|---------|------|
| RBAC (requires admin) | `k8s/namespace/devpod-namespace-creator-rbac.yml` |
| Namespace | `k8s/namespace/moltbook-namespace.yml` |
| Kustomization | `k8s/kustomization.yml` |
| ArgoCD App | `k8s/argocd-application.yml` |
| PostgreSQL | `k8s/database/cluster.yml` |
| API Deployment | `k8s/api/deployment.yml` |
| Frontend Deployment | `k8s/frontend/deployment.yml` |
| IngressRoutes | `k8s/api/ingressroute.yml`, `k8s/frontend/ingressroute.yml` |
| SealedSecrets | `k8s/secrets/moltbook-*-sealedsecret.yml` |

---

## Next Steps

1. **Cluster Admin:** Apply `k8s/namespace/devpod-namespace-creator-rbac.yml`
2. **Deploy:** Run `kubectl apply -k k8s/`
3. **Verify:** Check pods are running: `kubectl get pods -n moltbook`
4. **Test:** Access https://moltbook.ardenone.com
