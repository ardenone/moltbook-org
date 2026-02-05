# Namespace Creation Blocker

## Problem
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permissions to create namespaces on `ardenone-cluster`. This blocks deployment of the Moltbook platform which requires a dedicated `moltbook` namespace.

## Root Cause
Creating namespaces is a cluster-level operation that requires `cluster-admin` privileges. The devpod ServiceAccount only has namespace-scoped permissions within the `devpod` namespace.

## Solutions

### Option 1: Manual Namespace Creation (Quick Fix)
A cluster administrator runs:
```bash
kubectl create namespace moltbook
```

**Pros**: Fastest, no RBAC changes
**Cons**: Not GitOps, manual intervention required

### Option 2: Grant Namespace Creation Permissions (Recommended for Devpods)
Apply the RBAC manifest at `k8s/namespace/devpod-namespace-creator-rbac.yml`:

```bash
# Requires cluster-admin access
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

This grants the devpod ServiceAccount permissions to:
- Create namespaces
- Manage Roles and RoleBindings within new namespaces
- Create Traefik middlewares

**Pros**: Self-service namespace creation for developers
**Cons**: Requires one-time cluster-admin action

### Option 3: ArgoCD GitOps (Not Available)
The `k8s/argocd-application.yml` has `CreateNamespace=true`, but ArgoCD is not installed on `ardenone-cluster`.

**Pros**: True GitOps, self-healing
**Cons**: Requires ArgoCD installation (cluster-admin)

## Recommended Action
For immediate deployment, use **Option 2** - apply the RBAC manifest once as cluster-admin, then the devpod can create namespaces self-service.

## Current Status
- Namespace `moltbook`: Not found
- devpod ServiceAccount: Cannot create namespaces
- ArgoCD: Not installed on this cluster
- RBAC manifest: Ready at `k8s/namespace/devpod-namespace-creator-rbac.yml`
