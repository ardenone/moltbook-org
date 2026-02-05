# BEAD MO-1OB3 SUMMARY: RBAC - Create Moltbook Namespace and ServiceAccount

**Date**: 2026-02-05
**Bead ID**: mo-1ob3
**Title**: Fix: RBAC - create moltbook namespace and ServiceAccount
**Status**: BLOCKED - Requires cluster-admin action
**Priority**: P1 (High)

## Task Description

Task mo-3ttq is BLOCKED because namespace 'moltbook' does not exist. Need cluster-admin to either:
1. kubectl create namespace moltbook
2. Apply k8s/NAMESPACE_SETUP_REQUEST.yml with RBAC
3. Install ArgoCD first then apply k8s/argocd-application.yml

## Investigation Summary

### Verification Results (2026-02-05 13:34 UTC)

| Check | Result | Command |
|-------|--------|---------|
| Namespace `moltbook` exists | NOT EXISTS | `kubectl get namespace moltbook` |
| ClusterRole `namespace-creator` exists | NOT EXISTS | `kubectl get clusterrole namespace-creator` |
| ClusterRoleBinding `devpod-namespace-creator` exists | NOT EXISTS | `kubectl get clusterrolebinding devpod-namespace-creator` |
| Devpod SA can create namespaces | FORBIDDEN | `kubectl auth can-i create namespaces` |
| Devpod SA can create ClusterRole | FORBIDDEN | `kubectl auth can-i create clusterrole` |
| Devpod SA can create ClusterRoleBinding | FORBIDDEN | `kubectl auth can-i create clusterrolebinding` |

### Root Cause

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the necessary permissions to:
1. Create new namespaces (cluster-scoped resource)
2. Create ClusterRoles (cluster-scoped resource)
3. Create ClusterRoleBindings (cluster-scoped resource)

This is a **Kubernetes security feature** that prevents privilege escalation - a ServiceAccount cannot grant itself elevated permissions.

### Existing Manifests Are Valid

The following manifests exist and are valid:
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Combined RBAC + namespace creation
- `k8s/namespace/moltbook-namespace.yml` - Namespace only
- `k8s/namespace/moltbook-rbac.yml` - Namespace-scoped RBAC (Role + RoleBinding)
- `k8s/namespace/devpod-namespace-creator-rbac.yml` - ClusterRole + ClusterRoleBinding

## Action Required

### For Cluster Admin

A cluster administrator must run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This single command creates:
1. **ClusterRole**: `namespace-creator` - Grants create/get/list/watch on namespaces
2. **ClusterRoleBinding**: `devpod-namespace-creator` - Binds to devpod:default ServiceAccount
3. **Namespace**: `moltbook` - The target namespace for deployment

### After Cluster-Admin Applies RBAC

Once the RBAC is applied, the devpod can:
1. Verify permissions: `kubectl auth can-i create namespaces`
2. Apply namespace-scoped RBAC: `kubectl apply -f k8s/namespace/moltbook-rbac.yml`
3. Deploy Moltbook: `kubectl apply -k k8s/`

## Bead Created

**mo-1ge8** (P0 - Critical): "BLOCKER: Cluster-admin required - Apply NAMESPACE_SETUP_REQUEST.yml for moltbook namespace"

This bead tracks the cluster-admin action required to proceed with deployment.

## Related Documentation

- `MOLTBOOK_RBAC_BLOCKER_STATUS.md` - Comprehensive RBAC blocker documentation
- `BLOCKER_MO_2I4I_SUMMARY.md` - Previous RBAC blocker investigation
- `BLOCKER_MO_3N94_CLUSTER_ADMIN_Rbac.md` - Cluster admin requirement analysis
- `k8s/namespace/README.md` - Namespace setup instructions

## Next Steps

1. **Cluster-admin applies** `k8s/NAMESPACE_SETUP_REQUEST.yml` (mo-1ge8)
2. **Verify** resources exist:
   - `kubectl get clusterrole namespace-creator`
   - `kubectl get clusterrolebinding devpod-namespace-creator`
   - `kubectl get namespace moltbook`
3. **Close** mo-1ge8 after verification
4. **Proceed** with mo-3ttq (Moltbook deployment)

## Security Considerations

The `namespace-creator` ClusterRole follows the principle of least privilege:
- **Granted**: `create`, `get`, `list`, `watch` on namespaces
- **NOT granted**: `delete` on namespaces (prevents accidental deletion)
- **NOT granted**: Access to other cluster-scoped resources
- **NOT granted**: `escalate` or `impersonate` verbs (prevents privilege escalation)

---

**Status**: BLOCKED - Awaiting cluster-admin action
**Blocking**: mo-3ttq (Moltbook deployment)
**Estimated time for cluster-admin**: 2 minutes (one-time setup)
**Generated**: 2026-02-05 13:34 UTC by claude-glm-delta (mo-1ob3)
