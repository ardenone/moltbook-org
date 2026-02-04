# Moltbook Deployment Blocker Summary - 2026-02-04

**Bead ID:** mo-saz
**Status:** BLOCKED - Namespace creation requires cluster-admin intervention
**Date:** 2026-02-04 16:59 UTC

---

## Executive Summary

The Moltbook platform deployment to ardenone-cluster is **blocked** due to insufficient RBAC permissions for the devpod ServiceAccount to create namespaces. All Kubernetes manifests are complete and validated, but deployment cannot proceed without the `moltbook` namespace being created first.

---

## Current State

### 1. Deployment Manifests - READY ✅

All Kubernetes manifests are complete and ready for deployment:

**Location 1:** `/home/coder/Research/moltbook-org/k8s/`
**Location 2:** `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`

| Component | Manifest | Status |
|-----------|----------|--------|
| Namespace | `namespace/moltbook-namespace.yml` | Ready |
| RBAC | `namespace/moltbook-rbac.yml` | Ready |
| PostgreSQL (CNPG) | `database/cluster.yml` | Ready |
| Redis | `redis/deployment.yml` | Ready |
| API Backend | `api/deployment.yml` | Ready |
| Frontend | `frontend/deployment.yml` | Ready |
| SealedSecrets | `secrets/*.yml` | Ready |
| IngressRoutes | `api/ingressroute.yml`, `frontend/ingressroute.yml` | Ready |

### 2. Cluster Infrastructure - READY ✅

| Component | Status | Namespace |
|-----------|--------|-----------|
| CloudNativePG (CNPG) | Running | cnpg-system |
| SealedSecrets | Running | sealed-secrets |
| Traefik Ingress | Running | traefik |

### 3. Namespace - BLOCKED ❌

```
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```

---

## Blocker Details

### Permission Analysis

The devpod ServiceAccount lacks:
- `namespaces` resource creation permission at cluster scope
- Required ClusterRole/ClusterRoleBinding for namespace creation

### Current ClusterRoleBindings

```
devpod-rolebinding-controller → ClusterRole/devpod-rolebinding-controller
  - Can: get, list, watch namespaces (but NOT create)
  - Can: manage RoleBindings

k8s-observer-devpod-binding → ClusterRole/mcp-k8s-observer-namespace-resources
  - Limited read-only permissions
```

### Missing Resources

1. **ClusterRole:** `namespace-creator` (defined in manifests but not applied)
2. **ClusterRoleBinding:** `devpod-namespace-creator` (defined in manifests but not applied)

---

## Resolution Options

### Option 1: Cluster Admin Creates Namespace (Fastest)

```bash
# A cluster administrator runs:
kubectl create namespace moltbook
```

Then from devpod:
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-rbac.yml
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

### Option 2: Apply RBAC Manifest (Recommended for Long-term)

```bash
# A cluster administrator runs:
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

Then from devpod:
```bash
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

### Option 3: Deploy to Existing Namespace

Modify manifests to deploy to an existing namespace (e.g., `devpod` namespace itself).

---

## Post-Blocker Deployment Steps

Once namespace is created, deployment proceeds as:

```bash
# 1. Verify namespace exists
kubectl get namespace moltbook

# 2. Apply RBAC for the namespace
kubectl apply -f k8s/namespace/moltbook-rbac.yml

# 3. Apply SealedSecrets (they will be decrypted by sealed-secrets controller)
kubectl apply -f k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml
kubectl apply -f k8s/secrets/moltbook-db-credentials-sealedsecret.yml
kubectl apply -f k8s/secrets/moltbook-api-sealedsecret.yml

# 4. Deploy all resources with Kustomize
kubectl apply -k k8s/

# 5. Verify deployment
kubectl get pods -n moltbook
kubectl get svc -n moltbook
kubectl get ingressroutes -n moltbook
```

---

## Deployment Architecture

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance)
  │   ├─ moltbook-postgres-rw Service (ReadWrite)
  │   ├─ moltbook-postgres-ro Service (ReadOnly)
  │   └─ moltbook-postgres Service
  │
  ├─ moltbook-redis (Deployment, 1 replica)
  │   └─ moltbook-redis Service
  │
  ├─ moltbook-db-init (Deployment, 1 replica)
  │   └─ Initializes database schema via ConfigMap
  │
  ├─ moltbook-api (Deployment, 2 replicas)
  │   └─ moltbook-api Service
  │       └─ IngressRoute: api-moltbook.ardenone.com
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service
          └─ IngressRoute: moltbook.ardenone.com
```

---

## Images Used

- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`
- `redis:7-alpine`
- PostgreSQL: `ghcr.io/cloudnative-pg/postgresql:16` (via CNPG)

---

## Related Beads

**Blocker Bead Created:**
- **mo-32c** [P0] - Create moltbook namespace in ardenone-cluster

**Other Related Beads:**
- mo-hfs, mo-3rs, mo-drj, mo-2fr, mo-bai, mo-3iz - All related to namespace creation
- mo-9qx, mo-wm2, mo-37h - Frontend build errors (separate issue)
- mo-1uo - Container image build trigger

---

## GitOps Status

**IMPORTANT:** ArgoCD is **NOT** installed in ardenone-cluster.

The ArgoCD Application manifest at `k8s/argocd-application.yml` references:
- **Source:** `https://github.com/moltbook-org/moltbook-org.git` (incorrect, should be ardenone-cluster)
- **Path:** `k8s`
- **Target:** `moltbook` namespace

Since ArgoCD is not available, deployment must be done via `kubectl apply` after namespace is created.

---

## Verification Commands (After Namespace Created)

```bash
# Check all pods are running
kubectl get pods -n moltbook

# Check services
kubectl get svc -n moltbook

# Check IngressRoutes
kubectl get ingressroutes -n moltbook

# Check CNPG cluster
kubectl get cluster -n moltbook
kubectl describe cluster moltbook-postgres -n moltbook

# Check database initialization
kubectl logs -n moltbook deployment/moltbook-db-init --tail=50

# Test API health
curl https://api-moltbook.ardenone.com/health

# Test frontend
curl https://moltbook.ardenone.com
```

---

## Next Steps

1. **IMMEDIATE:** Request cluster-admin to either:
   - Create the `moltbook` namespace manually, OR
   - Apply the RBAC manifest: `k8s/namespace/devpod-namespace-creator-rbac.yml`

2. **FOLLOW-UP:** Once namespace is created, run deployment steps above

3. **VERIFICATION:** Test endpoints at:
   - `https://moltbook.ardenone.com` (Frontend)
   - `https://api-moltbook.ardenone.com` (API)

---

**Generated:** 2026-02-04
**Bead:** mo-saz
