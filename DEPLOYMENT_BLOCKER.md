# Moltbook Deployment Blocker - Namespace Creation Permissions

## Status: 🔴 BLOCKED

**Bead**: mo-cx8
**Blocker Bead**: mo-1e6t
**Date**: 2026-02-04
**Last Verified**: 2026-02-04 19:30 UTC

## Problem Summary

The Moltbook Kubernetes deployment is **blocked** because the devpod ServiceAccount lacks the necessary cluster-level permissions to:

1. **Create namespaces** at cluster scope
2. **Apply ClusterRole/ClusterRoleBinding** for RBAC setup
3. **Create the moltbook namespace** required for all platform resources

## Current State

```bash
# Permission check results:
$ kubectl auth can-i create namespace
no  # ❌ BLOCKED

# Existing infrastructure:
$ kubectl get clusterrole namespace-creator
Error from server (NotFound)  # ❌ Does not exist

$ kubectl get clusterrolebinding devpod-namespace-creator
Error from server (NotFound)  # ❌ Does not exist

$ kubectl get namespace moltbook
Error from server (NotFound)  # ❌ Does not exist
```

## Required Action: Cluster Admin Intervention

### Option 1: One-Click Setup (Recommended) ✅

A cluster administrator should run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

**This single command creates:**
- ✅ `namespace-creator` ClusterRole (grants namespace/role/rolebinding creation)
- ✅ `devpod-namespace-creator` ClusterRoleBinding (binds to devpod ServiceAccount)
- ✅ `moltbook` namespace with proper labels

**After this is applied, mo-cx8 can proceed autonomously with:**
```bash
kubectl apply -k k8s/
```

### Option 2: Alternative Approaches

#### A) Minimal RBAC + Manual Namespace Creation
```bash
# Apply RBAC only (as cluster admin):
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml

# Then create namespace (from devpod):
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

#### B) Manual Namespace Only (Least Preferred)
```bash
# Create namespace directly (as cluster admin):
kubectl apply -f k8s/NAMESPACE_REQUEST.yml

# Then proceed with deployment (from devpod):
kubectl apply -k k8s/
```

⚠️ **Drawback**: Option 2B doesn't grant ongoing namespace management permissions to devpod.

## Deployment Readiness Checklist

Once the namespace exists and RBAC is applied, the following is **ready to deploy**:

### ✅ Kubernetes Resources (All Manifests Complete)
- [x] Namespace definition (`k8s/namespace/moltbook-namespace.yml`)
- [x] RBAC for devpod ServiceAccount (`k8s/namespace/moltbook-rbac.yml`)
- [x] SealedSecrets (encrypted secrets, safe for Git)
  - [x] API secrets (`k8s/secrets/moltbook-api-sealedsecret.yml`)
  - [x] PostgreSQL superuser (`k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml`)
  - [x] Database credentials (`k8s/secrets/moltbook-db-credentials-sealedsecret.yml`)
- [x] CloudNativePG PostgreSQL cluster (`k8s/database/cluster.yml`)
- [x] PostgreSQL schema ConfigMap (`k8s/database/schema-configmap.yml`)
- [x] Schema initialization deployment (`k8s/database/schema-init-deployment.yml`)
- [x] Redis deployment (`k8s/redis/deployment.yml`)
- [x] API backend deployment (`k8s/api/deployment.yml`)
- [x] Frontend deployment (`k8s/frontend/deployment.yml`)
- [x] Traefik IngressRoute for API (`k8s/api/ingressroute.yml`)
- [x] Traefik IngressRoute for frontend (`k8s/frontend/ingressroute.yml`)
- [x] Kustomization configuration (`k8s/kustomization.yml`)
- [x] ArgoCD Application manifest (`k8s/argocd-application.yml`)

### ✅ Container Images (Built and Pushed)
- [x] `ghcr.io/ardenone/moltbook-api:f04cb91`
- [x] `ghcr.io/ardenone/moltbook-frontend:f04cb91`

## Post-Unblock Deployment Steps

Once cluster admin applies `NAMESPACE_SETUP_REQUEST.yml`:

```bash
# 1. Verify namespace exists
kubectl get namespace moltbook

# 2. Verify RBAC permissions
kubectl auth can-i create namespace
kubectl auth can-i create deployment -n moltbook
kubectl auth can-i create clusterpool -n moltbook  # CNPG

# 3. Deploy all resources
kubectl apply -k k8s/

# 4. Verify deployment
kubectl get all -n moltbook
kubectl get clusterpool -n moltbook
kubectl get ingressroute -n moltbook

# 5. Check application health
kubectl get pods -n moltbook
kubectl logs -n moltbook -l app.kubernetes.io/component=api
kubectl logs -n moltbook -l app.kubernetes.io/component=frontend
```

## ArgoCD Integration

Optional: Deploy via ArgoCD instead of kubectl:

```bash
kubectl apply -f k8s/argocd-application.yml
```

This will create an ArgoCD Application that syncs the `k8s/` directory.

## Related Documentation

- **RBAC Setup**: `k8s/NAMESPACE_SETUP_REQUEST.yml` (primary)
- **RBAC Reference**: `k8s/namespace/devpod-namespace-creator-rbac.yml`
- **Namespace Only**: `k8s/NAMESPACE_REQUEST.yml`
- **Main Kustomization**: `k8s/kustomization.yml`

## Tracking

- **Original Bead**: mo-cx8 (this deployment task)
- **Blocker Bead**: mo-1e6t (priority 0 - critical)
- **Related**: mo-3c3c (original RBAC request documentation)
