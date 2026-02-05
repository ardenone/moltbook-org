# ArgoCD Installation Blocker - Cluster Admin Action Required

**Date:** 2026-02-05
**Bead ID:** mo-3ki8
**Status:** BLOCKED - Awaiting cluster-admin action
**Cluster:** ardenone-cluster

## Problem Statement

ArgoCD is not installed in `ardenone-cluster`. The devpod ServiceAccount lacks the required cluster-admin permissions to:

1. Create `devpod-argocd-manager` ClusterRoleBinding (binds `argocd-manager-role` to devpod SA)
2. Create ArgoCD CRDs (cluster-scoped resources)
3. Create `argocd` namespace (cluster-scoped resource)

## Current State

| Resource | Status | Details |
|----------|--------|---------|
| `argocd` namespace | NOT FOUND | Namespace does not exist |
| `argocd-manager-role` ClusterRole | EXISTS | Full cluster-admin permissions (wildcard verbs on all resources) |
| `devpod-argocd-manager` ClusterRoleBinding | NOT FOUND | This is the blocker |
| ArgoCD CRDs | PARTIAL | 4 argoproj.io CRDs exist, full installation incomplete |
| devpod SA permissions | INSUFFICIENT | Cannot create ClusterRoleBindings |

## Cluster Admin Action Required

Execute the following command as a cluster-admin:

```bash
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

Or apply the manifest:
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

## Verification Commands

After applying the ClusterRoleBinding, verify with:

```bash
# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-argocd-manager

# Verify devpod SA has cluster-admin permissions
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
kubectl auth can-i create customresourcedefinition --as=system:serviceaccount:devpod:default
```

## Post-RBAC Installation Steps

Once the ClusterRoleBinding is applied, ArgoCD can be installed from the devpod:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

## Related Files

- `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml` - ClusterRoleBinding manifest for cluster-admin to apply
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - Original setup request with detailed verification
- `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` - Official ArgoCD installation manifest

## Related Beads

This blocker is tracked by multiple beads (consolidation needed):
- mo-3ki8 (this bead) - BLOCKER: ArgoCD installation requires cluster-admin RBAC
- mo-1fbe - CLUSTER-ADMIN ACTION: Create devpod-argocd-manager ClusterRoleBinding
- mo-2ah8 - CLUSTER-ADMIN REQUIRED: Apply ArgoCD RBAC
- mo-1v8x - BLOCKER: Cluster-admin must apply devpod-argocd-manager ClusterRoleBinding
- mo-3muh - CLUSTER-ADMIN: Apply ARGOCD_SETUP_REQUEST.yml
- mo-28th - CLUSTER-ADMIN ACTION: Install ArgoCD
- mo-hrle - CLUSTER-ADMIN ACTION: Apply ArgoCD RBAC and install
- ...and many more duplicates

## Resolution Criteria

This blocker is resolved when:
1. [ ] ClusterRoleBinding `devpod-argocd-manager` exists
2. [ ] `argocd` namespace exists
3. [ ] ArgoCD pods are running in `argocd` namespace
4. [ ] ArgoCD API is accessible
