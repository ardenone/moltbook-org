# ArgoCD Installation Blocker Status

**Date**: 2026-02-05
**Bead**: mo-1fgm
**Status**: BLOCKED - Requires cluster-admin intervention

## Current State

| Component | Status | Notes |
|-----------|--------|-------|
| argocd namespace | NOT FOUND | Does not exist |
| ArgoCD CRDs | NOT INSTALLED | No applications.argoproj.io, appprojects.argoproj.io |
| argocd-installer ClusterRole | NOT FOUND | Needs creation |
| devpod-argocd-installer ClusterRoleBinding | NOT FOUND | Needs creation |
| Devpod SA permissions | INSUFFICIENT | Cannot create namespaces, CRDs, or ClusterRoles |

## Why This is Blocked

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin privileges. ArgoCD installation requires creating cluster-scoped resources:

- **CustomResourceDefinitions** (CRDs) - cluster-scoped
- **ClusterRoles** - cluster-scoped
- **ClusterRoleBindings** - cluster-scoped
- **Namespaces** - cluster-scoped

These can only be created by a cluster-admin.

## Resolution Steps

### Step 1: Cluster-Admin Applies RBAC

A cluster-admin (from a machine with cluster-admin access to ardenone-cluster) must run:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

This creates:
- `argocd-installer` ClusterRole (namespace + CRD + RBAC + ArgoCD resource permissions)
- `devpod-argocd-installer` ClusterRoleBinding (binds to devpod:default SA)
- `argocd` namespace

### Step 2: Verify RBAC is Applied

From the devpod, verify permissions are granted:

```bash
# Should return "yes"
kubectl auth can-i create customresourcedefinitions
kubectl auth can-i create namespaces
kubectl auth can-i create clusterroles

# Should exist
kubectl get clusterrole argocd-installer
kubectl get clusterrolebinding devpod-argocd-installer
kubectl get namespace argocd
```

### Step 3: Install ArgoCD

From the devpod, run:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Or use the local manifest:

```bash
kubectl apply -f k8s/argocd-install-manifest.yaml
```

### Step 4: Verify Installation

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check all pods are running
kubectl get pods -n argocd

# Verify CRDs are installed
kubectl get crd | grep argoproj.io
```

### Step 5: Deploy Moltbook Application

```bash
kubectl apply -f k8s/argocd-application.yml
```

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-218h | ADMIN: Cluster Admin Action - Apply ArgoCD RBAC for mo-1fgm | P0 | OPEN |
| mo-1l3s | ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml for mo-1fgm | P0 | OPEN |
| mo-hhbp | BLOCKER: Cluster-admin needed to apply ArgoCD RBAC permissions | P0 | OPEN |
| mo-1fgm | CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments | P1 | BLOCKED |

## Verification Script

Run the verification script to check prerequisites:

```bash
bash k8s/verify-argocd-ready.sh
```

This will show which prerequisites are met and which are missing.

## Impact

- **BLOCKS**: mo-1fgm (Install ArgoCD)
- **BLOCKS**: Moltbook deployment via ArgoCD GitOps
- **BLOCKS**: All future applications using ArgoCD pattern in ardenone-cluster

## Alternative (Not Recommended)

An external ArgoCD instance exists at `argocd-manager.ardenone.com` (healthy), but local installation is required for:
- Full GitOps control within ardenone-cluster
- ApplicationSets for multi-app deployments
- Local cluster management pattern
