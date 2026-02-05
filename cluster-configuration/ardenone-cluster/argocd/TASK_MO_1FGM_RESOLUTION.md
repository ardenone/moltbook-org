# Task mo-1fgm Resolution: ArgoCD Installation for GitOps Deployments

**Task ID**: mo-1fgm
**Title**: CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
**Status**: BLOCKED - Requires Cluster-Admin Action
**Date**: 2026-02-05

---

## Executive Summary

The task to install ArgoCD in ardenone-cluster is **blocked by RBAC restrictions**. The devpod ServiceAccount lacks the cluster-admin permissions required to install ArgoCD (creating namespaces, CRDs, ClusterRoles).

**Solution**: A cluster-admin must apply the RBAC grant in `ARGOCD_SETUP_REQUEST.yml`, after which ArgoCD can be installed.

---

## Current State (2026-02-05 05:20 UTC)

| Component | Status | Details |
|-----------|--------|---------|
| Local ArgoCD | ❌ **NOT INSTALLED** | No argocd namespace, no ArgoCD CRDs |
| ArgoCD CRDs | ❌ **NOT INSTALLED** | No applications.argoproj.io, appprojects.argoproj.io |
| argocd-installer ClusterRole | ❌ **DOES NOT EXIST** | RBAC not yet applied |
| devpod-argocd-installer ClusterRoleBinding | ❌ **DOES NOT EXIST** | RBAC not yet applied |
| devpod RBAC | ❌ **INSUFFICIENT** | Cannot create namespaces, CRDs, or ClusterRoles |
| External ArgoCD | ✅ **ONLINE** | `argocd-manager.ardenone.com` health check returns "ok" |
| argocd-proxy | ✅ **RUNNING** | Read-only proxy in devpod namespace |

---

## Root Cause

The current devpod ServiceAccount (`system:serviceaccount:devpod:default`) only has read-only permissions for cluster-scoped resources:
- `get`, `list`, `watch` namespaces (read-only)
- `get`, `list`, `watch` customresourcedefinitions (read-only)
- `get`, `list`, `watch` clusterroles (read-only)

ArgoCD installation requires cluster-admin level permissions for:
1. Creating the `argocd` namespace
2. Installing CRDs (Applications, AppProjects, etc.)
3. Creating ClusterRoles and ClusterRoleBindings for ArgoCD components
4. Deploying ArgoCD core components (API server, repo-server, application-controller, etc.)

---

## Resolution Path

### Step 1: Cluster-Admin Applies RBAC Grant

```bash
# From a cluster-admin workstation (OUTSIDE devpod):
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

This creates:
- `argocd-installer` ClusterRole with all necessary permissions
- `devpod-argocd-installer` ClusterRoleBinding granting devpod ServiceAccount access
- `argocd` namespace

### Step 2: Install ArgoCD (from devpod)

```bash
# FROM devpod (after RBAC is applied):
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

### Step 4: Deploy Moltbook Application

```bash
# Apply the Moltbook ArgoCD Application
kubectl apply -f k8s/argocd-application.yml

# Sync the application (or wait for auto-sync)
argocd app sync moltbook --server argocd-server.argocd.svc.cluster.local
```

---

## Verification Commands

### Check Current Status

```bash
# Check argocd namespace (should not exist yet)
kubectl get namespace argocd
# Expected: Error from server (NotFound)

# Check ArgoCD CRDs (should not exist yet)
kubectl get crd | grep -E "applications\.argoproj\.io|appprojects\.argoproj\.io"
# Expected: (empty)

# Check devpod SA permissions
kubectl auth can-i create namespaces --all-namespaces
# Expected: no

kubectl auth can-i create customresourcedefinitions --all-namespaces
# Expected: no
```

---

## Files Prepared

1. **ARGOCD_SETUP_REQUEST.yml** - RBAC manifest for cluster-admin approval
2. **argocd-install.yml** - Official ArgoCD v2.13+ installation manifest (1.8MB)
3. **BLOCKER.md** - Detailed blocker analysis
4. **ARGOCD_INSTALL_REQUIRED.md** - Cluster admin action guide

---

## Related Beads

- **mo-1fgm** - Current task: CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- **mo-1l3s** (P0) - ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml for mo-1fgm

---

## Actions Taken

1. Verified current RBAC status - devpod SA lacks cluster-admin permissions
2. Confirmed argocd namespace does NOT exist
3. Confirmed ArgoCD CRDs are NOT installed
4. Confirmed argocd-installer ClusterRole does NOT exist
5. Confirmed devpod-argocd-installer ClusterRoleBinding does NOT exist
6. Verified external ArgoCD at argocd-manager.ardenone.com is healthy (returns "ok")
7. Created bead **mo-1l3s** (P0) to track cluster-admin action required

---

## Cluster Admin Instructions

To resolve this blocker, a cluster-admin must:

```bash
# Step 1: Apply RBAC grant for ArgoCD installation
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml

# Step 2: Verify RBAC was applied (from devpod)
kubectl get clusterrole argocd-installer
kubectl get clusterrolebinding devpod-argocd-installer
kubectl get namespace argocd
```

Once RBAC is applied, the devpod can complete the installation:

```bash
# Step 3: Install ArgoCD (from devpod, after RBAC)
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Step 4: Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Step 5: Apply Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

---

**Last Updated**: 2026-02-05 05:20 UTC
**Status**: 🔴 BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Related Beads**: mo-1fgm (task), mo-1l3s (P0 - cluster-admin action required)
