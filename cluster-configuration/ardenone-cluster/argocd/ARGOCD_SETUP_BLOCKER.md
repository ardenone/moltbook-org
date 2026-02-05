# ArgoCD Setup Blocker - Cluster-Admin Action Required

**Date**: 2026-02-05
**Bead**: mo-1qcw
**Status**: BLOCKED - Requires cluster-admin action

## Problem

The devpod ServiceAccount lacks `cluster-admin` permissions required to install ArgoCD in ardenone-cluster. Specifically:

- Cannot create `ClusterRoleBindings` (cluster-scoped resource)
- Cannot create `CustomResourceDefinitions` (cluster-scoped resource)
- Cannot create `Namespaces` (cluster-scoped resource)

## Current State

### ArgoCD Status
- **ardenone-cluster ArgoCD**: NOT INSTALLED
  - `argocd` namespace: Does NOT exist
  - `devpod-argocd-manager` ClusterRoleBinding: Does NOT exist
- **External ArgoCD** (argocd-manager.ardenone.com): HEALTHY (HTTP 200)
  - This is the alternative path for ArgoCD management

### Existing RBAC Resources
- `argocd-manager-role` ClusterRole: EXISTS (wildcard permissions, reusable)
- `argocd-manager-role-binding` ClusterRoleBinding: EXISTS
  - Bound to `kube-system:argocd-manager` (NOT devpod ServiceAccount)

## Required Cluster-Admin Action

### Step 1: Apply the RBAC setup manifest
```bash
# From a machine with cluster-admin access to ardenone-cluster:
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

This creates:
1. `ClusterRoleBinding/devpod-argocd-manager` - Grants devpod access to argocd-manager-role
2. `Namespace/argocd` - The ArgoCD namespace

### Step 2: Verify the RBAC was applied
```bash
kubectl get clusterrolebinding devpod-argocd-manager
kubectl get namespace argocd
```

### Step 3: From devpod, install ArgoCD
```bash
# After cluster-admin applies RBAC, devpod can install ArgoCD:
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

## Alternative Path

If ArgoCD installation in ardenone-cluster is not required, the external ArgoCD at argocd-manager.ardenone.com is healthy and can be used for GitOps management.

## Related Beads

- **mo-3rqc**: CRITICAL: Install ArgoCD in ardenone-cluster (BLOCKED)
- **mo-1qcw**: ADMIN: Cluster-admin action needed (this bead)
- **mo-2zir**: Existing cluster-admin action request
- **mo-5e25**: Existing cluster-admin action request
- **mo-3k53**: Existing cluster-admin action request

## Verification Commands

```bash
# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-argocd-manager

# Check if argocd namespace exists
kubectl get namespace argocd

# Check devpod permissions (from devpod)
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
kubectl auth can-i create customresourceds.apiextensions.k8s.io --as=system:serviceaccount:devpod:default
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:devpod:default
```
