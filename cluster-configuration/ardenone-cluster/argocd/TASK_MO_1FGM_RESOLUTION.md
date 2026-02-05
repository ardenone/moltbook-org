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

## Current State (2026-02-05 05:23 UTC)

| Component | Status | Details |
|-----------|--------|---------|
| Local ArgoCD | ❌ **NOT INSTALLED** | No argocd namespace, no ArgoCD CRDs |
| ArgoCD CRDs | ❌ **NOT INSTALLED** | No applications.argoproj.io, appprojects.argoproj.io |
| argocd-manager-role ClusterRole | ✅ **EXISTS** | Has wildcard permissions (reusable) |
| argocd-manager-role-binding | ✅ **EXISTS** | But bound to kube-system:argocd-manager only |
| devpod-argocd-manager ClusterRoleBinding | ❌ **DOES NOT EXIST** | Needs cluster-admin to create |
| devpod RBAC | ❌ **INSUFFICIENT** | Cannot create ClusterRoleBindings |
| External ArgoCD | ✅ **ONLINE** | `argocd-manager.ardenone.com` health check returns "ok" |
| argocd-proxy | ✅ **RUNNING** | Read-only proxy in devpod namespace |

---

## Root Cause

The current devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin permissions:
- Cannot create ClusterRoleBindings (cluster-scoped resource)
- Cannot create namespaces (cluster-scoped resource)
- Cannot create customresourcedefinitions (cluster-scoped resource)

**Good News**: An `argocd-manager-role` ClusterRole with wildcard permissions already exists in the cluster. It's currently bound only to `kube-system:argocd-manager`. We can reuse this ClusterRole by creating a ClusterRoleBinding for the devpod ServiceAccount.

**Bad News**: Creating a ClusterRoleBinding requires cluster-admin permissions, which the devpod does not have.

ArgoCD installation requires cluster-admin level permissions for:
1. Creating ClusterRoleBindings to grant devpod access to `argocd-manager-role`
2. Creating the `argocd` namespace (optional - ArgoCD creates it)
3. Installing CRDs (Applications, AppProjects, etc.)
4. Deploying ArgoCD core components (API server, repo-server, application-controller, etc.)

---

## Resolution Path

### Step 1: Cluster-Admin Creates ClusterRoleBinding

```bash
# From a cluster-admin workstation (OUTSIDE devpod):
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

This binds the existing `argocd-manager-role` ClusterRole to the devpod's default ServiceAccount.

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

# Check existing argocd-manager-role
kubectl get clusterrole argocd-manager-role
# Expected: EXISTS with wildcard permissions

# Check existing argocd-manager-role-binding
kubectl get clusterrolebinding argocd-manager-role-binding -o yaml
# Expected: EXISTS, bound to kube-system:argocd-manager only

# Check devpod SA permissions for creating ClusterRoleBindings
kubectl auth can-i create clusterrolebindings --all-namespaces
# Expected: no

# Check if devpod can use argocd-manager-role
kubectl auth can-i use clusterrole/argocd-manager-role
# Expected: no (not bound to devpod SA)
```

---

## Files Prepared

1. **CLUSTER_ADMIN_ACTION.yml** - Single ClusterRoleBinding manifest (simplified approach)
2. **CLUSTER_ADMIN_ACTION_REQUIRED.md** - Detailed cluster admin instructions
3. **ARGOCD_SETUP_REQUEST.yml** - Alternative RBAC setup (creates new ClusterRole)
4. **argocd-install.yml** - Official ArgoCD v2.13+ installation manifest (1.8MB)
5. **ARGOCD_INSTALL_REQUIRED.md** - Cluster admin action guide

---

## Related Beads

- **mo-1fgm** - Current task: CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- **mo-21wr** (P0) - BLOCKER: ArgoCD installation requires cluster-admin RBAC

---

## Actions Taken

1. Verified current RBAC status - devpod SA lacks cluster-admin permissions
2. Confirmed argocd namespace does NOT exist
3. Confirmed ArgoCD CRDs are NOT installed
4. Confirmed argocd-manager-role ClusterRole EXISTS (with wildcard permissions)
5. Confirmed argocd-manager-role-binding exists but bound to kube-system:argocd-manager only
6. Confirmed devpod-argocd-manager ClusterRoleBinding does NOT exist
7. Verified external ArgoCD at argocd-manager.ardenone.com is healthy (returns "ok")
8. Updated ARGOCD_SETUP_REQUEST.yml to reuse existing argocd-manager-role
9. Created bead **mo-21wr** (P0) to track cluster-admin action required

---

## Cluster Admin Instructions

To resolve this blocker, a cluster-admin must:

```bash
# Step 1: Create ClusterRoleBinding (simplified approach - recommended)
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml

# OR equivalently via kubectl create:
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default

# Step 2: Verify RBAC was applied (from devpod)
kubectl get clusterrolebinding devpod-argocd-manager
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

**Last Updated**: 2026-02-05 05:31 UTC
**Status**: 🔴 BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Related Beads**: mo-1fgm (task), mo-1x7x (P0 - cluster-admin action required)

## Latest Verification (2026-02-05 05:31 UTC)

Created focused blocker bead **mo-1x7x** for cluster-admin action:
- Confirmed argocd namespace does NOT exist
- Confirmed devpod-argocd-manager ClusterRoleBinding does NOT exist
- Confirmed devpod SA cannot create namespaces or CRDs
- CLUSTER_ADMIN_ACTION.yml is ready for cluster-admin to apply

## Latest Verification (2026-02-05 05:27 UTC)

Created focused blocker bead **mo-2m9f** after comprehensive verification:
- Confirmed argocd namespace does NOT exist
- Confirmed argocd-installer ClusterRole does NOT exist
- Confirmed devpod-argocd-installer ClusterRoleBinding does NOT exist
- Confirmed devpod SA cannot create CRDs, ClusterRoles, or ClusterRoleBindings
- Confirmed external ArgoCD at argocd-manager.ardenone.com is healthy (returns "ok")

**Simplified Resolution Path**: Use CLUSTER_ADMIN_ACTION.yml which binds the existing `argocd-manager-role` ClusterRole (wildcard permissions) to devpod SA. This is simpler than creating a new ClusterRole.
