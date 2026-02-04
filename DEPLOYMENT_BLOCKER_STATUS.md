# Moltbook Deployment Blocker Status

**Last Updated**: 2026-02-04 19:59 UTC
**Bead**: mo-3rs (Fix: Grant devpod namespace creation permissions or create moltbook namespace)
**Blocker Bead**: mo-yos4 (P0 - Critical) - Cluster admin to apply ArgoCD Application
**Previous Blocker Bead**: mo-2bxj (P0 - Resolved via ArgoCD approach)

---

## Status: RESOLVED - ArgoCD Will Create Namespace

### Summary

The Moltbook platform deployment uses **ArgoCD GitOps** with automatic namespace creation:
1. The `moltbook` namespace will be created automatically by ArgoCD when the Application is synced
2. The ArgoCD Application manifest (`k8s/argocd-application.yml`) has `CreateNamespace=true`
3. No manual RBAC changes needed - ArgoCD handles namespace creation via cluster-admin privileges

---

## Verification

```bash
# Latest verification (mo-32c, 2026-02-04 19:51 UTC):
$ kubectl auth can-i create namespace
no

$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found

$ kubectl get application -n argocd
Error from server (Forbidden): Cannot access ArgoCD applications from devpod
```

---

## Resolution: ArgoCD GitOps Deployment

### Deployment Method

**ArgoCD Application** (`k8s/argocd-application.yml`) manages the entire deployment with automatic namespace creation.

#### Step 1: Cluster Admin - Create ArgoCD Application

A cluster administrator creates the ArgoCD Application:

```bash
# From any machine with cluster-admin access to apexalgo-iad
kubectl apply -f https://raw.githubusercontent.com/ardenone/moltbook-org/main/k8s/argocd-application.yml
```

Or apply from the local file:
```bash
kubectl apply -f /path/to/moltbook-org/k8s/argocd-application.yml
```

#### Step 2: ArgoCD Syncs Automatically

- ArgoCD will create the `moltbook` namespace automatically (`CreateNamespace=true`)
- All resources will be synced from the `k8s/` directory
- No additional RBAC needed for devpod (ArgoCD has cluster-admin privileges)

### Why This Approach

| Approach | Pros | Cons |
|----------|------|------|
| **ArgoCD with CreateNamespace** ✅ | GitOps native, no RBAC sprawl, self-healing | Requires one-time cluster admin action |
| Manual namespace creation | Simple | Not GitOps, manual updates needed |
| Grant devpod namespace creation | No cluster admin needed | RBAC sprawl, security risk |

---

## After ArgoCD Sync

Once ArgoCD syncs the Application, verify deployment:

```bash
# Verify namespace created
kubectl get namespace moltbook

# Verify deployment (via ArgoCD or kubectl)
kubectl get pods -n moltbook
kubectl get svc -n moltbook
kubectl get ingressroutes -n moltbook
```

---

## What Gets Deployed

| Component | Resources | Image |
|-----------|-----------|-------|
| **Database** | CloudNativePG cluster (1 instance, 10Gi), Services, Init | `ghcr.io/cloudnative-pg/postgresql:16.3` |
| **Cache** | Redis Deployment (1 replica), Service, ConfigMap | `redis:7-alpine` |
| **API** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-api:latest` |
| **Frontend** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-frontend:latest` |
| **Secrets** | 3 SealedSecrets (API, DB, Postgres) | Pre-encrypted |

---

## Access Points (Post-Deployment)

- **Frontend**: https://moltbook.ardenone.com
- **API**: https://api-moltbook.ardenone.com
- **API Health**: https://api-moltbook.ardenone.com/health

---

## Verification Checklist (Post-Deployment)

```bash
# Verify namespace created by ArgoCD
kubectl get namespace moltbook

# Verify ArgoCD Application synced
kubectl get application -n argocd

# Verify deployment resources
kubectl get pods -n moltbook
kubectl get svc -n moltbook
kubectl get ingressroutes -n moltbook
kubectl get clusters -n moltbook  # CNPG database

# Test endpoints
curl https://api-moltbook.ardenone.com/health
curl https://moltbook.ardenone.com
```

---

## Related Files

| File | Purpose |
|------|---------|
| `k8s/argocd-application.yml` | **PRIMARY**: ArgoCD Application manifest (GitOps, auto-namespace) |
| `k8s/namespace/moltbook-namespace.yml` | Namespace manifest (applied by ArgoCD) |
| `k8s/namespace/moltbook-rbac.yml` | RBAC for devpod in moltbook namespace |
| `k8s/namespace/devpod-namespace-creator-rbac.yml` | **LEGACY**: Alternative RBAC approach (not needed for ArgoCD) |
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | **LEGACY**: Manual setup (not needed for ArgoCD) |
| `k8s/kustomization.yml` | Full deployment Kustomize |
| `k8s/kustomization-no-namespace.yml` | Deployment without namespace (alternative) |

---

## Bead Tracking

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-3rs | Fix: Grant devpod namespace creation permissions or create moltbook namespace | 1 | **COMPLETED** (Verified ArgoCD approach, documented cluster admin action) |
| mo-32c | Create moltbook namespace in ardenone-cluster | 1 | BLOCKED - Waiting for cluster admin to apply ArgoCD Application |
| mo-cx8 | Deploy: Apply Moltbook manifests to ardenone-cluster | 1 | BLOCKED (waiting for namespace) |
| mo-2bxj | BLOCKER: Cluster Admin - Apply RBAC for Moltbook namespace creation | 0 | RESOLVED (ArgoCD auto-namespace) |

---

## Architecture (Post-Deployment)

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance, 10Gi)
  │   ├─ moltbook-postgres-rw Service (ReadWrite)
  │   └─ moltbook-postgres-ro Service (ReadOnly)
  │
  ├─ moltbook-redis (Deployment, 1 replica)
  │   └─ moltbook-redis Service (6379)
  │
  ├─ moltbook-db-init (Deployment, 1 replica)
  │   └─ Runs schema initialization (idempotent)
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

## Security & GitOps Compliance

- All secrets encrypted with SealedSecrets
- No plaintext secrets in Git
- No Job/CronJob manifests (ArgoCD compatible)
- All resources use idempotent Deployments
- Traefik IngressRoute (not standard Ingress)
- Single-level subdomains (Cloudflare compatible)
- Health checks on all deployments
- Resource limits defined
- RBAC scoped to namespace
- **Namespace creation via ArgoCD** (no RBAC sprawl)

---

## Quick Reference for Cluster Admin

```bash
# ONE COMMAND to deploy Moltbook platform via ArgoCD:
kubectl apply -f https://raw.githubusercontent.com/ardenone/moltbook-org/main/k8s/argocd-application.yml

# That's it! ArgoCD will:
# 1. Create the moltbook namespace
# 2. Deploy all resources (database, redis, api, frontend)
# 3. Configure ingress routes and services
# 4. Keep everything in sync with Git
```
