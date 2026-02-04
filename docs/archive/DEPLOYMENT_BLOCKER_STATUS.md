# Moltbook Deployment Blocker Status

**Date:** 2026-02-04
**Bead:** mo-saz
**Status:** BLOCKED - Requires cluster-admin intervention

---

## Blocker Summary

The Moltbook deployment to ardenone-cluster is **blocked** due to insufficient RBAC permissions for the devpod ServiceAccount to create namespaces and cluster-level resources.

---

## Current State Analysis

### 1. Kubernetes Infrastructure - READY ✅

All required operators are installed and running:

| Component | Status | Namespace |
|-----------|--------|-----------|
| CloudNativePG (CNPG) | Running | cnpg-system |
| SealedSecrets | Running | sealed-secrets |
| Traefik Ingress | Running | traefik |

### 2. Deployment Manifests - READY ✅

All Kubernetes manifests are complete and validated:

- ✅ PostgreSQL CNPG cluster (`k8s/database/cluster.yml`)
- ✅ Redis deployment (`k8s/redis/`)
- ✅ API backend deployment (`k8s/api/deployment.yml`)
- ✅ Frontend deployment (`k8s/frontend/deployment.yml`)
- ✅ SealedSecrets for all credentials (`k8s/secrets/`)
- ✅ Traefik IngressRoute for `moltbook.ardenone.com` and `api-moltbook.ardenone.com`
- ✅ ArgoCD Application manifest (`k8s/argocd-application.yml`)
- ✅ Kustomize configuration (`k8s/kustomization.yml`)

### 3. RBAC Permissions - BLOCKED ❌

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks:

- `namespaces` resource creation permission at cluster scope
- `clusterroles.rbac.authorization.k8s.io` creation permission
- `clusterrolebindings.rbac.authorization.k8s.io` creation permission

**Current relevant ClusterRoleBindings:**
```
devpod-rolebinding-controller → ClusterRole/devpod-rolebinding-controller
  - Can: get, list, watch namespaces (but NOT create)
  - Can: manage RoleBindings
k8s-observer-devpod-binding → ClusterRole/mcp-k8s-observer-namespace-resources
  - Limited read-only permissions
```

---

## Required Actions

### Option 1: Apply RBAC Manifest (Recommended for long-term)

A cluster administrator needs to apply:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- `ClusterRole/namespace-creator` - grants namespace creation permissions
- `ClusterRoleBinding/devpod-namespace-creator` - binds to devpod SA

### Option 2: Manual Namespace Creation (Quick workaround)

A cluster administrator can manually create the namespace:

```bash
kubectl create namespace moltbook
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-rbac.yml
```

### Option 3: Alternative Namespace (If moltbook is unavailable)

Deploy to an existing namespace where the devpod SA has permissions (e.g., `devpod` namespace itself).

---

## Deployment Readiness Checklist

| Task | Status | Notes |
|------|--------|-------|
| PostgreSQL CNPG manifests | ✅ Complete | Ready to deploy |
| Redis deployment manifests | ✅ Complete | Ready to deploy |
| API backend manifests | ✅ Complete | Ready to deploy |
| Frontend manifests | ✅ Complete | Ready to deploy |
| SealedSecrets | ✅ Complete | All credentials encrypted |
| IngressRoute configuration | ✅ Complete | Domains configured |
| ArgoCD Application | ✅ Complete | GitOps ready |
| RBAC setup | ❌ BLOCKED | Requires cluster admin |
| Namespace creation | ❌ BLOCKED | Requires cluster admin |

---

## Post-Blocker Deployment Steps

Once RBAC is configured, the deployment proceeds as:

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace/moltbook-namespace.yml

# 2. Apply RBAC
kubectl apply -f k8s/namespace/moltbook-rbac.yml

# 3. Apply SealedSecrets
kubectl apply -f k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml
kubectl apply -f k8s/secrets/moltbook-db-credentials-sealedsecret.yml
kubectl apply -f k8s/secrets/moltbook-api-sealedsecret.yml

# 4. Deploy all resources
kubectl apply -k k8s/

# 5. Verify deployment
kubectl get pods -n moltbook
kubectl get svc -n moltbook
kubectl get ingressroutes -n moltbook
```

---

## Architecture Overview

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
  │   └─ Initializes database schema
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

## Related Beads

- **mo-363**: Blocker: RBAC setup required for Moltbook deployment
- **mo-saz**: This bead (Implementation: Deploy Moltbook platform)

---

## Next Steps

1. **Immediate**: Request cluster-admin to apply `k8s/namespace/devpod-namespace-creator-rbac.yml`
2. **Follow-up**: Once RBAC is granted, proceed with deployment steps above
3. **Verification**: Test endpoints at `https://moltbook.ardenone.com` and `https://api-moltbook.ardenone.com`

---

**Generated:** 2026-02-04
**Updated:** 2026-02-04
