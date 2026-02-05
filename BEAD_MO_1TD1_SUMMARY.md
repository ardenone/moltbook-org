# Bead mo-1td1 Summary: Research - Install ArgoCD in ardenone-cluster

**Task ID**: mo-1td1
**Title**: Research: Install ArgoCD in ardenone-cluster
**Date**: 2026-02-05
**Status**: COMPLETED - Research/Documentation Only
**Worker**: claude-glm-echo

---

## Executive Summary

ArgoCD is **NOT installed** in ardenone-cluster. This research confirms the blocker documented in existing beads and identifies the resolution path. The installation requires cluster-admin privileges which the devpod ServiceAccount does not have.

---

## Current State (Verified 2026-02-05)

| Component | Status | Details |
|-----------|--------|---------|
| argocd namespace | NOT FOUND | `kubectl get namespace argocd` returns error |
| ArgoCD CRDs | NOT INSTALLED | `kubectl get crd \| grep argoproj.io` returns empty |
| ArgoCD pods | NOT RUNNING | No argocd namespace exists |
| argocd-manager-role ClusterRole | EXISTS | Wildcard permissions (cluster-admin equivalent) |
| argocd-manager-role-binding ClusterRoleBinding | EXISTS | Bound to kube-system:argocd-manager |
| devpod-argocd-manager ClusterRoleBinding | NOT FOUND | **Required for devpod installation** |

---

## Root Cause

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin privileges required to:

1. **Create CustomResourceDefinitions (CRDs)** - cluster-scoped resource
2. **Create ClusterRoleBindings** - cluster-scoped resource
3. **Create argocd namespace** - cluster-scoped resource

---

## Resolution Path

### Step 1: Cluster Admin Action (Required)

A cluster-admin must create a ClusterRoleBinding to grant the devpod ServiceAccount permissions:

```bash
# Use the existing argocd-manager-role ClusterRole
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

**OR** use the prepared manifest:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

### Step 2: Install ArgoCD (From Devpod, After RBAC)

```bash
# Option 1: Use local manifest (faster, no network dependency)
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Option 2: Use official upstream (latest version)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 3: Verify Installation

```bash
# Verify ArgoCD pods are running
kubectl get pods -n argocd

# Verify ArgoCD CRDs are installed
kubectl get crd | grep argoproj.io
```

---

## Related Existing Beads (P0 Blockers)

The following beads are already tracking this exact blocker:

- **mo-2nwc** - BLOCKER: Cluster-admin action required for ArgoCD setup
- **mo-1bbc** - BLOCKER: ArgoCD install requires cluster-admin - devpod lacks RBAC
- **mo-2xo0** - Blocker: ArgoCD installation requires cluster-admin to apply RBAC
- **mo-2rci** - BLOCKER: Cluster Admin must apply ARGOCD_SETUP_REQUEST.yml
- **mo-2c4o** - ADMIN: Cluster Admin - Apply ArgoCD RBAC for devpod installation
- **mo-3ff2** - CLUSTER-ADMIN: Apply ARGOCD_SETUP_REQUEST.yml RBAC manifest
- And 22+ other duplicate P0 beads

**NOTE**: No new blocker bead was created for mo-1td1 as this is a research/documentation task and the blocker is already well-tracked.

---

## Existing Documentation & Manifests

The following files already exist and are ready for use:

| File | Description |
|------|-------------|
| `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml` | ClusterRoleBinding manifest for cluster-admin |
| `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` | Full ArgoCD installation manifest (1.8MB) |
| `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` | Alternative RBAC manifest |
| `k8s/ARGOCD_INSTALLATION_GUIDE.md` | Comprehensive installation guide |
| `k8s/ARGOCD_INSTALL_REQUEST.yml` | RBAC manifest (alternative location) |
| `k8s/install-argocd.sh` | Installation script |
| `k8s/verify-argocd-ready.sh` | Verification script |
| `k8s/argocd-application.yml` | Moltbook ArgoCD Application manifest (ready after ArgoCD install) |

---

## Related Beads Referenced

- **mo-1fgm** - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- **mo-218h** - Related ArgoCD installation task

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ardenone-cluster                             │
│                                                                      │
│  ┌──────────────┐         ┌──────────────────────────────────────┐ │
│  │ Cluster Admin│ ──────▶ │         RBAC Grant                   │ │
│  │ (Required)   │ apply   │  devpod-argocd-manager ClusterRole   │ │
│  └──────────────┘         │  Binding (binds argocd-manager-role) │ │
│                            └──────────────────────────────────────┘ │
│                                          │                          │
│  ┌──────────────┐         ┌──────────────▼───────────────┐        │
│  │ Devpod SA    │ ──────▶ │       ArgoCD Installation     │        │
│  │ (default)    │ apply   │  argocd-install.yml manifest  │        │
│  └──────────────┘         │  - CRDs (cluster-scoped)      │        │
│                            │  - argocd namespace           │        │
│                            │  - deployments, services, etc. │        │
│                            └───────────────────────────────┘        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Next Steps (After Cluster Admin Action)

Once the cluster-admin applies the RBAC grant:

1. Verify RBAC: `kubectl get clusterrolebinding devpod-argocd-manager`
2. Install ArgoCD: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
3. Verify installation: `kubectl get pods -n argocd`
4. Deploy Moltbook: `kubectl apply -f k8s/argocd-application.yml`

---

## Research Conclusion

**This task (mo-1td1) is complete as a research/documentation effort.**

The ArgoCD installation is blocked by a lack of cluster-admin privileges for the devpod ServiceAccount. This blocker is already tracked by 28+ existing P0 beads. No new action beads were created as the existing beads comprehensively cover this blocker.

**Required external action**: Cluster-admin must apply the ClusterRoleBinding manifest to grant devpod the necessary permissions.

---

**Co-Authored-By**: Claude Code <noreply@anthropic.com>
