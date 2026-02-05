# Task mo-dwxh Status: ADMIN: Cluster-admin - Install ArgoCD in ardenone-cluster

**Task ID**: mo-dwxh
**Title**: ADMIN: Cluster-admin - Install ArgoCD in ardenone-cluster
**Status**: BLOCKED - Requires cluster-admin RBAC
**Date**: 2026-02-05 13:20 UTC
**Worker**: claude-glm-india

---

## Executive Summary

Task mo-dwxh ("ADMIN: Cluster-admin - Install ArgoCD") was executed from a devpod but **failed to complete** because the devpod ServiceAccount lacks the cluster-admin privileges required to create ClusterRoleBindings.

**Resolution**: Existing blocker beads **mo-80sx (P0)** and **mo-y3id (P0)** track the cluster-admin action required. A cluster-admin must apply the RBAC manifest before ArgoCD can be installed.

---

## Current State (2026-02-05 13:08 UTC)

| Component | Status | Details |
|-----------|--------|---------|
| argocd namespace | NOT FOUND | Does not exist |
| ArgoCD CRDs | NOT INSTALLED | No applications.argoproj.io, appprojects.argoproj.io |
| argocd-manager-role ClusterRole | EXISTS | Has wildcard permissions (created 2025-09-07) |
| devpod-argocd-manager ClusterRoleBinding | NOT FOUND | **BLOCKER** - Cannot create from devpod |
| Devpod SA permissions | INSUFFICIENT | Cannot create ClusterRoleBindings, CRDs, or namespaces |

---

## Actions Attempted

1. **Attempted RBAC Application** (FAILED - 2026-02-05 13:20 UTC)
   ```bash
   kubectl create clusterrolebinding devpod-argocd-manager \
     --clusterrole=argocd-manager-role \
     --serviceaccount=devpod:default
   # Error: User "system:serviceaccount:devpod:default" cannot create resource "clusterrolebindings"
   ```

2. **Verified Permissions**
   - `kubectl auth can-i create clusterrolebindings` → **no**
   - `kubectl auth can-i create customresourcedefinitions` → **no**
   - `kubectl auth can-i create namespaces` → **no**

3. **Verified Existing Resources**
   - `argocd-manager-role` ClusterRole → **EXISTS** (wildcard permissions)
   - `argocd-manager-role-binding` ClusterRoleBinding → **EXISTS** (bound to kube-system:argocd-manager)
   - `devpod-argocd-manager` ClusterRoleBinding → **NOT FOUND** (needs cluster-admin)
   - `argocd` namespace → **NOT FOUND**
   - ArgoCD CRDs → **NOT FOUND**

4. **Existing Blocker Beads**
   - **mo-80sx (P0)**: CLUSTER-ADMIN ACTION - OPEN
   - **mo-y3id (P0)**: CLUSTER-ADMIN ACTION - OPEN

---

## Required Cluster-Admin Action

A cluster-admin (with direct access to ardenone-cluster) must run:

```bash
# Apply the ClusterRoleBinding manifest
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml

# Verify it was created
kubectl get clusterrolebinding devpod-argocd-manager
```

After the RBAC is applied, from the devpod run:

```bash
# Verify permissions are granted
kubectl auth can-i create clusterrolebindings
kubectl auth can-i create namespaces

# Install ArgoCD
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| **mo-80sx** | **CLUSTER-ADMIN ACTION: Apply devpod-argocd-manager ClusterRoleBinding for ArgoCD installation** | **P0** | **OPEN** |
| **mo-y3id** | **CLUSTER-ADMIN ACTION: Apply devpod-argocd-manager ClusterRoleBinding** | **P0** | **OPEN** |
| mo-dwxh | ADMIN: Cluster-admin - Install ArgoCD in ardenone-cluster | P1 | BLOCKED (waiting for mo-80sx/mo-y3id) |
| mo-1fgm | CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments | P1 | BLOCKED |
| mo-3ttq | Deploy Moltbook application via ArgoCD | P1 | BLOCKED |

---

## Files Referenced

1. **CLUSTER_ADMIN_ACTION.yml** - ClusterRoleBinding manifest (ready for cluster-admin)
2. **CLUSTER_ADMIN_ACTION_REQUIRED.md** - Detailed cluster admin instructions
3. **argocd-install.yml** - ArgoCD v2.13+ installation manifest (1.8MB)
4. **TASK_MO_1FGM_RESOLUTION.md** - Original task resolution documentation
5. **BLOCKER_STATUS.md** - Overall blocker status (updated)

---

## Next Steps

1. **Cluster-admin applies RBAC** (mo-1gnb)
2. **Devpod verifies permissions**
3. **Install ArgoCD** from argocd-install.yml
4. **Verify installation** (pods, CRDs, services)
5. **Apply Moltbook Application** manifest

---

**Last Updated**: 2026-02-05 13:20 UTC
**Status**: BLOCKED - Awaiting cluster-admin action (mo-80sx, mo-y3id)
**Priority**: P0 (Critical)

---

## Related Verification: mo-1rgl (2026-02-05)

Task mo-1rgl ("Fix: RBAC for moltbook namespace creation") re-verified the RBAC blocker:
- Confirmed `moltbook` namespace does NOT exist
- Confirmed `namespace-creator` ClusterRole does NOT exist
- Confirmed `devpod-namespace-creator` ClusterRoleBinding does NOT exist
- Confirmed devpod SA cannot create namespaces, ClusterRoles, or ClusterRoleBindings

**Note**: Per `k8s/DEPLOYMENT_PATH_DECISION.md`, PATH 2 (kubectl manual) was selected. This requires the simpler NAMESPACE_SETUP_REQUEST.yml instead of the full ArgoCD installation manifest.
