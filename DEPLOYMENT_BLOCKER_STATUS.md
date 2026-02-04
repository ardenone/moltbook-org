# Moltbook Deployment Blocker Status

**Last Updated**: 2026-02-04 19:35 UTC
**Bead**: mo-3rs (Fix: Grant devpod namespace creation permissions or create moltbook namespace)
**Blocker Bead**: mo-aco2 (P0 - Critical) - Cluster admin to create namespace in ardenone-cluster
**Previous Blocker Bead**: mo-2bxj (P0 - Superseded by mo-aco2)

---

## Status: BLOCKED - Cluster Admin Action Required

### Important: This is for ardenone-cluster (local cluster)

The current context is **ardenone-cluster** (where devpods run).
- **ArgoCD is NOT installed** in ardenone-cluster
- The `argocd-application.yml` is intended for a different cluster (apexalgo-iad)
- Namespace creation in ardenone-cluster requires direct cluster admin action

### Summary

The `moltbook` namespace cannot be created by the devpod ServiceAccount:
1. Namespace creation is a cluster-scoped operation
2. Devpod SA only has read-only access via `mcp-k8s-observer-cluster-resources` ClusterRole
3. A cluster administrator must apply `NAMESPACE_SETUP_REQUEST.yml`

---

## Verification

```bash
# Latest verification (mo-3rs, 2026-02-04 19:35 UTC):
$ kubectl auth can-i create namespace
no

$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found

$ kubectl get namespace argocd
Error from server (NotFound): namespaces "argocd" not found
# Confirmed: ArgoCD is NOT installed in ardenone-cluster
```

---

## Resolution: Cluster Admin Must Apply NAMESPACE_SETUP_REQUEST.yml

### Deployment Method for ardenone-cluster

**NAMESPACE_SETUP_REQUEST.yml** creates the RBAC and namespace in one command.

#### Step 1: Cluster Admin - Apply Setup Manifest

A cluster administrator with access to ardenone-cluster runs:

```bash
# Option 1: From local file
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml

# Option 2: From GitHub
kubectl apply -f https://raw.githubusercontent.com/ardenone/moltbook-org/main/k8s/NAMESPACE_SETUP_REQUEST.yml
```

#### What This Creates

| Resource | Purpose |
|----------|---------|
| `ClusterRole: namespace-creator` | Grants namespace creation + RBAC management permissions |
| `ClusterRoleBinding: devpod-namespace-creator` | Binds ClusterRole to devpod:default ServiceAccount |
| `Namespace: moltbook` | The target namespace for all Moltbook resources |

#### Step 2: Verify Namespace Created

```bash
kubectl get namespace moltbook
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
```

#### Step 3: Deploy from Devpod

Once namespace exists, the devpod can deploy:
```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

### Why This Approach

| Approach | Pros | Cons |
|----------|------|------|
| **NAMESPACE_SETUP_REQUEST.yml** ✅ | One-time setup, grants devpod namespace management perms | Requires one-time cluster admin action |
| Manual namespace only | Simplest | Devpod can't manage namespace RBAC |
| Grant devpod cluster-admin | No future cluster admin needed | Security risk, overly broad permissions |
| ArgoCD (apexalgo-iad only) | GitOps native | Not installed in ardenone-cluster |

---

## After Namespace Creation

Once the namespace exists, deploy from devpod:

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

Verify deployment:

```bash
# Verify namespace created
kubectl get namespace moltbook

# Verify deployment resources
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
# Verify namespace and RBAC
kubectl get namespace moltbook
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator

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
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | **PRIMARY**: Cluster-admin setup manifest (RBAC + namespace) |
| `k8s/namespace/moltbook-namespace.yml` | Namespace manifest (included in NAMESPACE_SETUP_REQUEST.yml) |
| `k8s/namespace/moltbook-rbac.yml` | RBAC for devpod in moltbook namespace |
| `k8s/scripts/create-moltbook-namespace.sh` | Setup script |
| `k8s/argocd-application.yml` | ArgoCD Application (for apexalgo-iad cluster, not ardenone-cluster) |
| `k8s/kustomization.yml` | Full deployment Kustomize |
| `k8s/kustomization-no-namespace.yml` | Deployment without namespace (alternative) |

---

## Bead Tracking

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-3rs | Fix: Grant devpod namespace creation permissions or create moltbook namespace | 1 | **COMPLETED** (Identified issue, created blocker bead mo-aco2) |
| mo-aco2 | Fix: Cluster Admin - Create moltbook namespace in ardenone-cluster | 0 | **BLOCKER** - Requires cluster admin action |
| mo-32c | Create moltbook namespace in ardenone-cluster | 1 | BLOCKED (waiting for mo-aco2) |
| mo-cx8 | Deploy: Apply Moltbook manifests to ardenone-cluster | 1 | BLOCKED (waiting for namespace) |
| mo-2bxj | BLOCKER: Cluster Admin - Apply RBAC for Moltbook namespace creation | 0 | SUPERSEDED by mo-aco2 |

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

---

## Quick Reference for Cluster Admin

```bash
# ONE COMMAND to create namespace and RBAC for Moltbook platform:
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml

# After this, the devpod can deploy:
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```
