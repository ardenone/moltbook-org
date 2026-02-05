# Namespace Creation Blocker - Moltbook Deployment

**Date**: 2026-02-05
**Bead**: mo-3uep
**Status**: BLOCKED - Requires cluster-admin action

## Summary

The `moltbook` namespace does not exist in the `ardenone-cluster`. The devpod ServiceAccount lacks permission to create namespaces at the cluster scope. A cluster administrator must create the namespace before deployment can proceed.

## Verified State (2026-02-05 13:20 UTC)

| Resource | Status | Details |
|----------|--------|---------|
| `moltbook` namespace | NOT FOUND | `kubectl get namespace moltbook` returns NotFound |
| `argocd` namespace | NOT FOUND | Separate blocker - see mo-ku75 |
| Devpod SA namespace creation | FORBIDDEN | Cannot create cluster-scoped resources |

### Verification Commands

```bash
# Verify namespace does not exist
kubectl get namespace moltbook
# Output: Error from server (NotFound): namespaces "moltbook" not found

# Verify devpod SA cannot create namespaces
kubectl auth can-i create namespaces
# Output: no

# Attempt to create namespace (will fail)
kubectl create namespace moltbook
# Output: Error from server (Forbidden): namespaces is forbidden:
#         User "system:serviceaccount:devpod:default" cannot create
#         resource "namespaces" at cluster scope
```

## Cluster Admin Action Required

**Choose one of the following options:**

### Option 1: Quick (30 seconds) - Namespace Only

```bash
kubectl create namespace moltbook
```

### Option 2: With RBAC Setup (Recommended)

This grants the devpod ServiceAccount permission to create namespaces in the future:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
1. `namespace-creator` ClusterRole (namespace permissions)
2. `devpod-namespace-creator` ClusterRoleBinding
3. `moltbook` namespace

### Option 3: Grant Full Cluster-Admin via Existing Role

Since `argocd-manager-role` already exists, grant full cluster-admin:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

## After Namespace Exists

Once the namespace is created (and RBAC is granted if using Option 2 or 3), deploy from the devpod:

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

## Deployment Path

Per `k8s/DEPLOYMENT_PATH_DECISION.md`, **PATH 2 (kubectl manual)** was selected:
- External ArgoCD exists at `argocd-manager.ardenone.com`
- Local ArgoCD installation blocked (mo-ku75)
- PATH 2 unblocks deployment immediately

## Related Beads

| Bead | Title | Priority | Status |
|------|-------|----------|--------|
| mo-3uep | Fix: Cluster-admin action - Create moltbook namespace | 1 | OPEN (this bead) |
| mo-3ttq | Moltbook deployment | 2 | BLOCKED (requires namespace) |
| mo-ku75 | CLUSTER-ADMIN ACTION: Apply devpod-argocd-manager CRB | 0 | OPEN (ArgoCD path) |
| mo-1rgl | Fix: RBAC for moltbook namespace creation | 1 | BLOCKED |

## Files Reference

| Purpose | File |
|---------|------|
| Namespace Setup Request (all-in-one) | `k8s/NAMESPACE_SETUP_REQUEST.yml` |
| Cluster Admin Action (full admin) | `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml` |
| Namespace only | `k8s/namespace/moltbook-namespace.yml` |
| Deployment manifest | `k8s/kustomization.yml` |
| Path decision documentation | `k8s/DEPLOYMENT_PATH_DECISION.md` |

## Success Criteria

- [ ] Cluster admin applies one of the options above
- [ ] `kubectl get namespace moltbook` returns successfully
- [ ] `kubectl apply -k k8s/` succeeds
- [ ] Pods are running in `moltbook` namespace
- [ ] Services are accessible via IngressRoutes
