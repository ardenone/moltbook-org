# Task Resolution: mo-17ws - CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster

**Task ID**: mo-17ws
**Title**: CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm
**Date**: 2026-02-05 12:58 UTC
**Status**: BLOCKED - Requires cluster-admin action
**Worker**: claude-glm-hotel

---

## Executive Summary

This task confirms that **ArgoCD is NOT installed** in ardenone-cluster and **requires cluster-admin intervention**. All necessary files have been prepared and documented. The devpod ServiceAccount lacks the required cluster-scoped permissions to install ArgoCD.

### Key Findings

| Component | Status | Details |
|-----------|--------|---------|
| argocd namespace | NOT FOUND | Does not exist in ardenone-cluster |
| ArgoCD CRDs | NOT INSTALLED | No applications.argoproj.io or appprojects.argoproj.io |
| argocd-manager-role ClusterRole | EXISTS | Full wildcard permissions (cluster-admin equivalent) |
| argocd-manager-role-binding | EXISTS | Bound to kube-system:argocd-manager (NOT devpod) |
| devpod-argocd-manager ClusterRoleBinding | NOT FOUND | **BLOCKER** - Needs cluster-admin to create |
| Devpod SA permissions | INSUFFICIENT | Cannot create namespaces, CRDs, or ClusterRoleBindings |

---

## Blocker Analysis

### Why This is Blocked

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) **cannot install ArgoCD** because:

1. **ArgoCD requires cluster-scoped resources**:
   - CustomResourceDefinitions (CRDs) - extends Kubernetes API
   - Namespaces (argocd namespace)
   - ClusterRoleBindings (for ArgoCD components)

2. **Devpod SA lacks cluster-admin permissions**:
   - Cannot create namespaces
   - Cannot create CRDs
   - Cannot create ClusterRoleBindings

3. **Existing infrastructure not accessible**:
   - `argocd-manager-role` ClusterRole exists with full permissions
   - But it's bound to `kube-system:argocd-manager`, NOT devpod SA

### Resolution Path

**A cluster-admin must execute** one of the following:

#### Option 1: Create ClusterRoleBinding (RECOMMENDED)

```bash
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

#### Option 2: Apply Prepared Manifest

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

Then from the devpod:

```bash
# Install ArgoCD
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Verify installation
kubectl get pods -n argocd
kubectl get crd | grep argoproj.io
```

---

## Files Prepared for Cluster-Admin Action

### 1. RBAC Manifests

| File | Purpose |
|------|---------|
| `CLUSTER_ADMIN_ACTION.yml` | Single ClusterRoleBinding manifest (simplest) |
| `ARGOCD_SETUP_REQUEST.yml` | Full RBAC + namespace manifest (alternative) |

### 2. Installation Manifest

| File | Purpose |
|------|---------|
| `argocd-install.yml` | Official ArgoCD v2.13+ installation manifest |

### 3. Documentation

| File | Purpose |
|------|---------|
| `ARGOCD_INSTALL_REQUIRED.md` | Comprehensive cluster-admin guide |
| `CLUSTER_ADMIN_ACTION_REQUIRED.md` | Quick-start instructions |
| `BLOCKER_STATUS.md` | Detailed blocker analysis |
| `INSTALLATION_STATUS.md` | Current state and next steps |

---

## Verification Commands

### Before Cluster-Admin Action (Current State)

```bash
# Verify argocd namespace does NOT exist
kubectl get namespace argocd
# Expected: Error from server (NotFound)

# Verify ArgoCD CRDs are NOT installed
kubectl get crd | grep argoproj.io
# Expected: (no output)

# Verify devpod-argocd-manager ClusterRoleBinding does NOT exist
kubectl get clusterrolebinding devpod-argocd-manager
# Expected: Error from server (NotFound)

# Verify argocd-manager-role EXISTS (reusable)
kubectl get clusterrole argocd-manager-role
# Expected: Shows ClusterRole with wildcard permissions
```

### After Cluster-Admin Action

```bash
# Verify ClusterRoleBinding was created
kubectl get clusterrolebinding devpod-argocd-manager
# Expected: Shows ClusterRoleBinding with roleRef to argocd-manager-role

# From devpod: Verify namespace creation permission
kubectl auth can-i create namespace
# Expected: yes

# From devpod: Install ArgoCD
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Verify ArgoCD pods are running
kubectl get pods -n argocd
# Expected: Shows argocd-server, argocd-repo-server, argocd-application-controller, etc.

# Verify CRDs are installed
kubectl get crd | grep argoproj.io
# Expected: Shows applications.argoproj.io, appprojects.argoproj.io, etc.
```

---

## Impact

### Blocked Tasks

| Bead ID | Title | Priority |
|---------|-------|----------|
| mo-1fgm | CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments | P1 |
| mo-saz | Moltbook platform deployment to ardenone-cluster | P0 |
| mo-23p | Related Moltbook deployment tasks | P0 |

### Dependent Applications

- **Moltbook** - Requires ArgoCD Application CRD
- All future GitOps-based deployments in ardenone-cluster

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ardenone-cluster                                 │
│                                                                      │
│  ┌──────────────┐                                                   │
│  │ Cluster Admin│ ──────────▶ CREATE ClusterRoleBinding             │
│  │              │             devpod-argocd-manager                  │
│  └──────────────┘                                                   │
│                           │                                          │
│                           ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ argocd-manager-role (ClusterRole)                            │  │
│  │ - Wildcard permissions on all resources (*)                   │  │
│  │ - Already exists in cluster                                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                           │                                          │
│                           ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ devpod-argocd-manager (ClusterRoleBinding)                   │  │
│  │ - Binds argocd-manager-role to devpod:default SA             │  │
│  │ - MUST be created by cluster-admin                           │  │
│  │ - Status: NOT FOUND (BLOCKER)                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                           │                                          │
│                           ▼                                          │
│  ┌──────────────┐                                                   │
│  │ Devpod SA    │ ◀──────────── Granted permissions                 │
│  │ (default)    │                                                     │
│  └──────────────┘                                                   │
│       │                                                              │
│       │ kubectl apply -f argocd-install.yml                         │
│       ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ ArgoCD Installation                                          │  │
│  │ - argocd namespace                                           │  │
│  │ - CRDs (15+ custom resources)                                │  │
│  │ - Deployments (server, repo-server, controller, etc.)         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Next Steps for Cluster-Admin

### Step 1: Apply RBAC (5 seconds)

```bash
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

### Step 2: Notify Devpod Team

Confirm that the ClusterRoleBinding has been created. The devpod can then proceed with ArgoCD installation.

### Step 3: Verify Installation (optional)

```bash
# From a cluster-admin workstation:
kubectl get clusterrolebinding devpod-argocd-manager
kubectl get namespace argocd
kubectl get pods -n argocd
```

---

## Related Documentation

- [ArgoCD Installation Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD manifests repository](https://github.com/argoproj/argo-cd)

---

**Prepared by**: Claude Code (mo-17ws)
**Last Updated**: 2026-02-05 13:02 UTC
**Status**: Awaiting cluster-admin action
**Estimated Time for Cluster-Admin**: 1 minute (single kubectl command)
**Blocker Bead**: mo-1fbe (P0) - Tracks cluster-admin action requirement
