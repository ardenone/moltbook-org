# Bead mo-1ob3 Summary: Fix: RBAC - create moltbook namespace and ServiceAccount

## Status: BLOCKED - Cluster Admin Action Required

## What Was Attempted

Task mo-1ob3 attempted to create the `moltbook` namespace and ServiceAccount for the Moltbook platform deployment.

## Blocker Identified

The devpod ServiceAccount lacks the necessary RBAC permissions to:
1. Create ClusterRole (`namespace-creator`)
2. Create ClusterRoleBinding (`devpod-namespace-creator`)
3. Create new namespaces at cluster scope

## Permissions Analysis

Current devpod ServiceAccount permissions:
- `namespaces`: get, list, watch (NOT create)
- `clusterroles`: NOT allowed
- `clusterrolebindings`: NOT allowed

Required for this task:
- `namespaces`: create, get, list, watch
- `clusterroles`: create (for namespace-creator)
- `clusterrolebindings`: create (for devpod-namespace-creator)

## Resolution Path

A **cluster-admin** must apply one of the following:

### Option 1: Complete Setup (Recommended)
```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
1. `namespace-creator` ClusterRole
2. `devpod-namespace-creator` ClusterRoleBinding
3. `moltbook` namespace with ArgoCD labels

### Option 2: RBAC Only + Namespace
```bash
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/namespace/moltbook-namespace.yml
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

### Option 3: ArgoCD GitOps (Requires ArgoCD Installed)
```bash
kubectl apply -f k8s/argocd-application.yml
```

ArgoCD will auto-create the namespace via `CreateNamespace=true`.

## New Bead Created

**mo-3h6c**: Fix: RBAC - cluster-admin must apply namespace-creator RBAC (Priority 0 - Critical)

This bead tracks the cluster-admin action required before mo-1ob3 can proceed.

## Related Documentation

- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Combined RBAC and namespace manifest
- `k8s/CLUSTER_ADMIN_README.md` - Detailed cluster admin instructions
- `CLUSTER_ADMIN_ACTION.md` - Action required for cluster admins

## Next Steps

1. **Cluster admin** applies `k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Verify namespace exists: `kubectl get namespace moltbook`
3. Resume mo-1ob3 to complete namespace setup
4. Proceed with mo-3ttq (Moltbook deployment)

## Generated

2026-02-05 by claude-glm-echo (mo-1ob3)
