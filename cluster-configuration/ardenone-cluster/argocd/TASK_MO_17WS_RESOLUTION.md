# Task mo-17ws Resolution: Cluster-Admin Action Required for ArgoCD Installation

**Date**: 2026-02-05 13:01 UTC
**Task**: mo-17ws - CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm
**Status**: BLOCKED - Requires cluster-admin intervention
**Blocker Bead**: mo-1v8x (P0) - "BLOCKER: Cluster-admin must apply devpod-argocd-manager ClusterRoleBinding for ArgoCD installation"

---

## Summary

This task confirmed that ArgoCD is NOT installed in ardenone-cluster and the devpod ServiceAccount lacks the cluster-admin permissions required to install it. A **cluster-admin must apply a single RBAC manifest** to enable ArgoCD installation.

---

## Current State (Verified 2026-02-05)

| Component | Status | Details |
|-----------|--------|---------|
| **argocd namespace** | NOT FOUND | `kubectl get namespace argocd` returns NotFound |
| **ArgoCD CRDs** | NOT INSTALLED | No `applications.argoproj.io`, `appprojects.argoproj.io` |
| **devpod-argocd-manager ClusterRoleBinding** | NOT FOUND | Cannot create from devpod (Forbidden) |
| **argocd-manager-role ClusterRole** | EXISTS | Full wildcard permissions (`*.*` with `[*]` verbs) |
| **argocd-manager-role-binding** | EXISTS | Bound to `kube-system:argocd-manager` SA (not devpod) |
| **Devpod SA Permissions** | INSUFFICIENT | Cannot create ClusterRoleBindings, Namespaces, or CRDs |

---

## Why This Is Blocked

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) has only namespace-scoped permissions via:
- `coder-workspace-manager` Role (devpod namespace only)
- `devpod-priority-user` ClusterRole (limited cluster-scoped permissions)
- `mcp-k8s-observer-*` ClusterRoles (read-only access)

ArgoCD installation requires creating **cluster-scoped resources**:
- CustomResourceDefinitions (CRDs) - extends Kubernetes API
- ClusterRoleBindings - grants cluster-wide permissions
- Namespaces - cluster-scoped resource

Only a `cluster-admin` can create these resources.

---

## Required Cluster-Admin Action

### Step 1: Apply RBAC Manifest (Cluster-Admin Only)

From a machine with cluster-admin access to ardenone-cluster:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

This creates:
1. **ClusterRoleBinding**: `devpod-argocd-manager`
   - Binds `argocd-manager-role` (cluster-admin equivalent) to `devpod:default` ServiceAccount

### Step 2: Create argocd Namespace (Cluster-Admin Only)

```bash
kubectl create namespace argocd
```

Or use ARGOCD_SETUP_REQUEST.yml which includes both resources.

### Step 3: Verify RBAC is Applied

From the devpod, verify permissions are granted:

```bash
# Should return "yes"
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
kubectl auth can-i create customresourcedefinitions --as=system:serviceaccount:devpod:default
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:devpod:default

# Should exist
kubectl get clusterrolebinding devpod-argocd-manager
kubectl get namespace argocd
```

### Step 4: Install ArgoCD (From Devpod)

Once RBAC is applied, from the devpod:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

### Step 5: Verify Installation

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check all pods
kubectl get pods -n argocd

# Verify CRDs are installed
kubectl get crd | grep argoproj.io
```

---

## Files Prepared

| File | Purpose | Target |
|------|---------|--------|
| `CLUSTER_ADMIN_ACTION.yml` | Single ClusterRoleBinding manifest | **Cluster-admin must apply this** |
| `ARGOCD_SETUP_REQUEST.yml` | ClusterRoleBinding + Namespace manifest | Alternative with namespace included |
| `argocd-install.yml` | Official ArgoCD v2.13+ installation manifest | Devpod applies after RBAC |
| `CLUSTER_ADMIN_ACTION_REQUIRED.md` | Complete cluster-admin documentation | Detailed instructions |
| `ARGOCD_INSTALL_REQUIRED.md` | Installation guide | Post-RBAC steps |

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| **mo-1v8x** | **BLOCKER: Cluster-admin must apply devpod-argocd-manager ClusterRoleBinding** | **P0** | **OPEN** |
| mo-17ws | CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm | P1 | BLOCKED |
| mo-1fgm | CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments | P1 | BLOCKED |

---

## Security Considerations

### Why This Requires Cluster Admin

- ArgoCD requires **cluster-scoped resources** (CRDs, ClusterRoles, ClusterRoleBindings)
- CRDs extend the Kubernetes API with new resource types
- Only `cluster-admin` can create cluster-scoped resources
- The devpod ServiceAccount is intentionally limited to **namespace-scoped permissions**

### Resource Requirements

ArgoCD requires:
- **Memory**: ~2GB minimum for production use
- **CPU**: ~1 core minimum
- **Storage**: Not required (stateless components)

---

## Next Steps

1. **Cluster-admin applies** `CLUSTER_ADMIN_ACTION.yml`
2. **Cluster-admin creates** `argocd` namespace
3. **Verify RBAC** with `kubectl get clusterrolebinding devpod-argocd-manager`
4. **Devpod installs** ArgoCD with `kubectl apply -f argocd-install.yml`
5. **Verify installation** with `kubectl get pods -n argocd`
6. **Deploy Moltbook** via ArgoCD Application manifest
7. **Close blocker bead** mo-1v8x
8. **Resume task** mo-1fgm

---

**Prepared by**: Claude Code (task mo-17ws)
**Date**: 2026-02-05 13:01 UTC
**Priority**: P0 - CRITICAL BLOCKER
**Estimated Time**: 5 minutes (one-time cluster-admin action)
**Related Beads**: mo-1v8x (P0 - cluster-admin action required), mo-1fgm (blocked task)
