# BLOCKER: mo-1ob3 - Namespace Creation Requires Cluster-Admin

## Bead Information
- **Bead ID**: mo-1ob3
- **Title**: Fix: RBAC - create moltbook namespace and ServiceAccount
- **Status**: BLOCKED - Requires cluster-admin intervention
- **Priority**: P0 (Critical)
- **Generated**: 2026-02-05 13:33 by claude-glm-alpha

## Summary

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permission to create namespaces on `ardenone-cluster`. The `moltbook` namespace does not exist and cannot be created without cluster-admin privileges.

## Root Cause

Creating namespaces is a cluster-level operation that requires `cluster-admin` privileges. The devpod ServiceAccount only has namespace-scoped permissions within the `devpod` namespace.

## Current State

| Resource | Status |
|----------|--------|
| Namespace `moltbook` | Does not exist |
| Namespace `argocd` | Does not exist |
| Devpod SA namespace creation | Forbidden |
| NAMESPACE_SETUP_REQUEST.yml | Ready to apply |

## Verification

```bash
# Namespace does not exist
kubectl get namespace moltbook
# Error: NotFound

# Devpod SA cannot create namespaces
kubectl create namespace moltbook
# Error: Error from server (Forbidden): error when creating "/home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml": clusterroles.rbac.authorization.k8s.io is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "clusterroles" in API group "rbac.authorization.k8s.io" at the cluster scope
```

## Required Action: Cluster-Admin

A cluster-admin must apply one of the following options:

### Option 1: Combined RBAC + Namespace Setup (Recommended)

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
1. **ClusterRole**: `namespace-creator` - Permissions to create, get, list, watch namespaces
2. **ClusterRoleBinding**: `devpod-namespace-creator` - Binds to devpod:default ServiceAccount
3. **Namespace**: `moltbook` - The required namespace for Moltbook deployment

### Option 2: Namespace Only (Quick Fix)

```bash
kubectl create namespace moltbook
```

Then the devpod can apply RBAC afterward with `kubectl apply -f k8s/namespace/moltbook-rbac.yml`

### Option 3: ArgoCD GitOps (Not Available)

The `k8s/argocd-application.yml` has `CreateNamespace=true`, but ArgoCD is not installed on `ardenone-cluster`.

## Post-Setup Steps (After Cluster-Admin Action)

Once the cluster-admin applies the manifest:

1. Verify namespace exists: `kubectl get namespace moltbook`
2. Apply RBAC: `kubectl apply -f k8s/namespace/moltbook-rbac.yml`
3. Deploy resources: `kubectl apply -k k8s/`
4. Monitor deployment: `kubectl get pods -n moltbook -w`

## Files Ready for Deployment

Once namespace exists:
- `k8s/namespace/moltbook-rbac.yml` - RBAC for devpod to manage moltbook resources
- `k8s/kustomization.yml` - Full deployment manifest
- `k8s/kustomization-no-namespace.yml` - Alternative kustomization for pre-created namespace

## Related Documentation

- `CLUSTER_ADMIN_ACTION.md` - Cluster admin action request
- `NAMESPACE_CREATION_BLOCKER.md` - Detailed analysis of namespace creation blockers
- `MOLTBOOK_RBAC_BLOCKER_STATUS.md` - Overall RBAC blocker status

## Related Beads

- **mo-3ttq**: BLOCKER - requires moltbook namespace to exist
- **mo-1ge8**: BLOCKER - Cluster-admin required to apply NAMESPACE_SETUP_REQUEST.yml
- **mo-3grc**: BLOCKER - Cluster-admin required to create moltbook namespace and RBAC
- **mo-3h6c**: BLOCKER - cluster-admin must apply namespace-creator RBAC

## Impact

This blocker prevents:
- Task mo-3ttq from deploying the Moltbook platform
- All subsequent deployment tasks
- Integration testing of the Moltbook application

## Resolution Path

1. Cluster-admin applies `k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Namespace `moltbook` is created
3. Devpod ServiceAccount gains namespace creation permissions
4. Task mo-1ob3 can proceed with RBAC configuration
5. Task mo-3ttq can proceed with Moltbook deployment

---

**Status**: BLOCKED - Awaiting cluster-admin action
**Next Action**: Cluster-admin must run `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
