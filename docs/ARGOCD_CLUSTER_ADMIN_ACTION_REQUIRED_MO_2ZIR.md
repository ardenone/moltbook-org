# mo-2zir: ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml

## Status: BLOCKED - Requires Cluster-Admin Action

## Summary

ArgoCD installation cannot proceed from the devpod because the devpod ServiceAccount lacks the necessary RBAC permissions to create cluster-scoped resources (ClusterRoleBinding, Namespace).

## Current State (Verified 2026-02-05)

### What Exists
- `argocd-manager-role` ClusterRole: **EXISTS** with wildcard permissions (`*` on all resources)
- `argocd-manager-role-binding` ClusterRoleBinding: **EXISTS** but bound to `kube-system:argocd-manager`
- `argocd-install.yml`: **EXISTS** (1.8MB official ArgoCD manifest)

### What's Missing
- `argocd` namespace: **NOT FOUND**
- `devpod-argocd-manager` ClusterRoleBinding: **NOT FOUND**
- ArgoCD pods: **NOT FOUND** (namespace doesn't exist)

### Why It's Blocked
The devpod ServiceAccount (`devpod:default`) cannot create:
1. **ClusterRoleBindings** - cluster-scoped resource
2. **Namespaces** - cluster-scoped resource
3. **CustomResourceDefinitions** - cluster-scoped resource (needed for ArgoCD)

## Required Action

A cluster-admin must run:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

This manifest creates:
1. `devpod-argocd-manager` ClusterRoleBinding (grants devpod SA access to argocd-manager-role)
2. `argocd` namespace

### After Cluster-Admin Applies RBAC

From the devpod, run:
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

## Duplicate/Related Beads

This issue has been tracked in multiple beads (all require the same cluster-admin action):
- mo-2zir (this bead) - marked CLOSED incorrectly
- mo-2xo0 - Blocker: ArgoCD installation requires cluster-admin
- mo-2rci - BLOCKER: Cluster Admin must apply ARGOCD_SETUP_REQUEST.yml
- mo-2c4o - ADMIN: Cluster Admin - Apply ArgoCD RBAC

## Verification Commands

```bash
# Check if namespace exists
kubectl get namespace argocd

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-argocd-manager

# Check if ArgoCD is installed
kubectl get pods -n argocd

# Check devpod SA permissions
kubectl auth can-i create namespace --all-namespaces
kubectl auth can-i create clusterrolebinding
```

## ARGOCD_SETUP_REQUEST.yml Contents

```yaml
---
# Step 1: Create ClusterRoleBinding to grant devpod access to existing argocd-manager-role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devpod-argocd-manager
subjects:
- kind: ServiceAccount
  name: default
  namespace: devpod
roleRef:
  kind: ClusterRole
  name: argocd-manager-role
  apiGroup: rbac.authorization.k8s.io

---
# Step 2: Create the argocd namespace
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
```
