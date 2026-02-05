# ArgoCD Installation Status - ardenone-cluster

**Task**: mo-1fgm - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
**Date**: 2026-02-05 05:26 UTC
**Status**: 🔴 BLOCKED - Requires cluster-admin privileges

**Blocker Bead**: mo-21wr (P0) - "BLOCKER: ArgoCD installation requires cluster-admin RBAC"

---

## Executive Summary

ArgoCD is **NOT installed** in ardenone-cluster. The devpod ServiceAccount lacks the cluster-admin privileges required to install ArgoCD (which requires creating CustomResourceDefinitions).

### Impact

- **BLOCKS** all GitOps-based deployments
- **BLOCKS** Moltbook platform deployment (mo-saz, mo-23p)
- **BLOCKS** automated synchronization of Kubernetes manifests with Git

---

## Current State Verification

| Check | Status | Details |
|-------|--------|---------|
| argocd namespace | ❌ NotFound | `kubectl get namespace argocd` - does not exist |
| ArgoCD CRDs | ❌ Not Installed | `kubectl get crd \| grep argoproj.io` - no results |
| ArgoCD pods | ❌ Not Running | No argocd namespace exists |
| Cluster-admin access | ❌ Denied | Devpod SA cannot create CRDs |

### Current Identity

```
system:serviceaccount:devpod:default
```

### Missing Permissions

```bash
# Cannot create CRDs (cluster-scoped resource)
$ kubectl auth can-i create customresourcedefinitions
no

# Cannot create ClusterRoleBindings (cluster-scoped resource)
$ kubectl auth can-i create clusterrolebindings
Error from server (Forbidden): User cannot impersonate serviceaccounts
```

---

## Solution: Cluster Admin Action Required

### Action Bead Created

**Bead ID**: `mo-21wr`
**Priority**: 0 (Critical)
**Title**: BLOCKER: ArgoCD installation requires cluster-admin RBAC

### Commands for Cluster Admin

**Simplified approach** (reuse existing argocd-manager-role ClusterRole):

```bash
# Step 1: Create ClusterRoleBinding to bind devpod SA to existing argocd-manager-role
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default

# Step 2: (Alternative) Direct installation by cluster-admin
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Step 2: Wait for ArgoCD pods to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Step 3: Verify installation
kubectl get pods -n argocd
kubectl get crd | grep argocd
```

---

## What ArgoCD Installation Provides

### Custom Resource Definitions (15+ CRDs)

- `applications.argoproj.io` - Application CRD for GitOps deployments
- `appprojects.argoproj.io` - Project CRD for logical groupings
- `applicationsets.argoproj.io` - ApplicationSet for multi-cluster deployments
- And 12+ other ArgoCD CRDs

### Core Components

- `argocd-server` - API server and web UI
- `argocd-repo-server` - Git repository sync server
- `argocd-application-controller` - Application sync controller
- `argocd-dex-server` - OAuth/OIDC authentication
- `argocd-redis` - Caching layer

### GitOps Capabilities

- Automated synchronization of Kubernetes manifests with Git
- Declarative application deployment
- Rollback and drift detection
- Multi-cluster management

---

## After ArgoCD Is Installed

Once the cluster-admin installs ArgoCD, the devpod can:

### 1. Deploy Moltbook via ArgoCD Application

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

### 2. Verify Moltbook Deployment

```bash
# Check ArgoCD Application sync status
kubectl get application moltbook -n argocd

# Check Moltbook resources
kubectl get all -n moltbook
```

### 3. Access ArgoCD UI (Optional)

```bash
# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## Related Beads

### Blockers Created by This Task

- **mo-21wr** (P0): BLOCKER: ArgoCD installation requires cluster-admin RBAC

### Related Beads (Blocked)

- **mo-saz** (P0): Moltbook platform deployment to ardenone-cluster
- **mo-23p** (P0): Related Moltbook deployment tasks
- **mo-2q8h**: Apply devpod-namespace-creator RBAC (also requires cluster-admin)

---

## Files Created/Updated

### Installation Manifests

- `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` - Official ArgoCD installation manifest (1.8MB)
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - RBAC request (alternative approach)
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_INSTALL_REQUIRED.md` - Cluster admin action guide

### Application Manifests

- `k8s/argocd-application.yml` - Moltbook ArgoCD Application manifest (ready to apply after ArgoCD is installed)

### Documentation

- `k8s/install-argocd.sh` - Installation script (requires cluster-admin)
- `k8s/verify-argocd-ready.sh` - Prerequisites verification script
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Complete installation guide

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ardenone-cluster                             │
│                                                                      │
│  ┌──────────────┐         ┌──────────────────────────────────────┐ │
│  │ Cluster Admin│ ──────▶ │         ArgoCD Namespace              │ │
│  │ (Required)   │ apply   │  ┌─────────────────────────────────┐  │ │
│  └──────────────┘         │  │ argocd-install.yml manifest     │  │ │
│                            │  │ - CRDs (cluster-scoped)        │  │ │
│                            │  │ - argocd namespace              │  │ │
│                            │  │ - deployments, services, etc.   │  │ │
│  ┌──────────────┐         │  └─────────────────────────────────┘  │ │
│  │ Devpod SA    │ ──────▶ │                                       │ │
│  │ (limited)   │ apply   │  ┌─────────────────────────────────┐  │ │
│  └──────────────┘         │  │ Moltbook Application             │  │ │
│                            │  │ argocd-application.yml          │  │ │
│                            │  │ - Syncs k8s/ manifests          │  │ │
│                            │  │ - Creates moltbook namespace     │  │ │
│                            │  └─────────────────────────────────┘  │ │
│                            └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Problem: `kubectl get crd | grep argocd` returns nothing

**Solution**: ArgoCD CRDs were not installed. Re-run the installation as cluster-admin:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

### Problem: Pods stuck in `Pending` or `ImagePullBackOff`

**Solution**: Check pod status and logs:
```bash
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd
kubectl logs <pod-name> -n argocd
```

### Problem: ArgoCD Application not syncing

**Solution**: Check ArgoCD application status and logs:
```bash
kubectl get application moltbook -n argocd -o yaml
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

---

## Next Steps

### Option 1: RBAC Grant Approach (Recommended for devpod-based installation)
1. **Cluster Admin**: Apply RBAC grant: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml`
2. **Devpod**: Install ArgoCD: `bash k8s/install-argocd.sh`
3. **Verify**: Run `kubectl get pods -n argocd` to confirm installation
4. **Devpod**: Apply Moltbook Application: `kubectl apply -f k8s/argocd-application.yml`
5. **Verify**: Run `kubectl get application moltbook -n argocd` to confirm sync

### Option 2: Direct Cluster-Admin Installation
1. **Cluster Admin**: Install ArgoCD directly: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
2. **Cluster Admin**: Apply Moltbook Application: `kubectl apply -f k8s/argocd-application.yml`
3. **Devpod**: Verify: Run `kubectl get application moltbook -n argocd`

---

**Last Updated**: 2026-02-05 05:35 UTC
**Verified by**: mo-1fgm (claude-glm-foxtrot worker)
**Re-verified**: 2026-02-05 05:30 UTC (zai-bravo worker)
**Status**: 🔴 BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Estimated Time**: 5 minutes (one-time cluster setup)

## Related Blocker Beads (2026-02-05)

- **mo-2dpt** (P0): ADMIN: Cluster Admin Action - Install ArgoCD in ardenone-cluster - OPEN
- **mo-1fgm** (P1): CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments - BLOCKED

**Documentation**: See `BLOCKER_STATUS.md` for detailed blocker resolution steps.
