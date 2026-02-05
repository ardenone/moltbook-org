# Task mo-dwxh Status: ArgoCD Installation Blocked - Cluster-Admin Action Required

**Task ID**: mo-dwxh
**Title**: ADMIN: Cluster-admin - Install ArgoCD in ardenone-cluster
**Status**: BLOCKED - Requires Cluster-Admin Access
**Date**: 2026-02-05

---

## Executive Summary

This task requires cluster-admin level access to install ArgoCD in ardenone-cluster. The current devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the necessary permissions to:

1. Create ClusterRoleBindings (cluster-scoped resource)
2. Create CustomResourceDefinitions (cluster-scoped resource)
3. Create namespaces (cluster-scoped resource)

---

## Current State (2026-02-05)

| Component | Status | Details |
|-----------|--------|---------|
| ArgoCD namespace | ❌ **NOT INSTALLED** | No `argocd` namespace exists |
| ArgoCD CRDs | ❌ **NOT INSTALLED** | No applications.argoproj.io, appprojects.argoproj.io |
| argocd-manager-role ClusterRole | ✅ **EXISTS** | Has wildcard permissions |
| devpod-argocd-manager ClusterRoleBinding | ❌ **DOES NOT EXIST** | Needs cluster-admin to create |
| argocd-install.yml | ✅ **READY** | 1.8MB manifest ready to apply |
| CLUSTER_ADMIN_ACTION.yml | ✅ **READY** | RBAC manifest ready to apply |

---

## Root Cause

The devpod runs as `system:serviceaccount:devpod:default` which cannot create cluster-scoped resources:

```
$ kubectl auth can-i create clusterrolebindings --all-namespaces
no

$ kubectl auth whoami
ATTRIBUTE                                           VALUE
Username                                            system:serviceaccount:devpod:default
Groups                                              [system:serviceaccounts system:serviceaccounts:devpod system:authenticated]
```

---

## Required Actions (Cluster-Admin Only)

### Step 1: Apply RBAC (from cluster-admin workstation)

```bash
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

Or using the prepared manifest:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

### Step 2: Install ArgoCD (from devpod, after RBAC is applied)

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

### Step 3: Verify Installation

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check all ArgoCD components
kubectl get all -n argocd

# Verify CRDs are installed
kubectl get crd | grep argoproj.io
```

---

## Files Prepared

1. **CLUSTER_ADMIN_ACTION.yml** - ClusterRoleBinding manifest (binds argocd-manager-role to devpod SA)
2. **argocd-install.yml** - Official ArgoCD v2.13+ installation manifest (1.8MB)

---

## Related Blocked Tasks

- **mo-3ttq** (P0) - Moltbook deployment - BLOCKED: ArgoCD not installed
- **mo-1fgm** - ArgoCD installation task - BLOCKED: Cluster-admin RBAC required

---

## Devpod Verification Commands

```bash
# Check ArgoCD namespace (should not exist yet)
kubectl get namespace argocd

# Check ArgoCD CRDs (should not exist yet)
kubectl get crd | grep argoproj.io

# Check argocd-manager-role ClusterRole (should exist)
kubectl get clusterrole argocd-manager-role

# Check if devpod-argocd-manager binding exists (should NOT exist)
kubectl get clusterrolebinding devpod-argocd-manager

# Verify RBAC permissions (should be "no")
kubectl auth can-i create clusterrolebindings --all-namespaces
kubectl auth can-i create customresourcedefinitions --all-namespaces
kubectl auth can-i create namespace --all-namespaces
```

---

**Last Updated**: 2026-02-05
**Status**: 🔴 BLOCKED - Requires cluster-admin access
**Priority**: P0 (Critical)
**Executor**: claude-glm-foxtrot
