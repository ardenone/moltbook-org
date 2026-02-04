# Task mo-y5o Summary: ArgoCD Installation Analysis

**Task ID:** mo-y5o
**Title:** CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date:** 2026-02-04
**Status:** BLOCKED - Cluster Admin Action Required
**Last Verification:** 2026-02-04 22:29 UTC

## Executive Summary

The task to install ArgoCD locally in ardenone-cluster is **blocked by RBAC permissions**. The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin privileges required to install ArgoCD (create CRDs, cluster-scoped resources).

**VERIFICATION COMPLETED:**
- ArgoCD namespace: **NOT FOUND** (verified via kubectl)
- Installation attempt: **FAILED** - Forbidden errors on CRD, ClusterRole, ClusterRoleBinding creation
- RBAC status: **NOT APPLIED** - requires cluster-admin action

## Current State

| Component | Status | Details |
|-----------|--------|---------|
| Local ArgoCD | Not Installed | `kubectl get namespace argocd` returns NotFound |
| ArgoCD CRDs | Not Installed | Only Argo Rollouts CRDs exist |
| RBAC (argocd-installer) | Not Applied | Requires cluster-admin to apply |
| devpod permissions | Insufficient | Cannot create CRDs, namespaces, cluster-scoped resources |
| Installation attempt | Failed | Forbidden errors on all cluster-scoped resources |

## Verification Results (2026-02-04 22:29 UTC)

### Namespace Check
```bash
$ kubectl get namespace argocd
Error from server (NotFound): namespaces "argocd" not found
```

### Installation Attempt - Forbidden Errors
```bash
# Namespace creation failed
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"

# CRD creation failed
Error from server (Forbidden): customresourcedefinitions.apiextensions.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "customresourcedefinitions"

# ClusterRole creation failed
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"

# ClusterRoleBinding creation failed
Error from server (Forbidden): clusterrolebindings.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterrolebindings"
```

## Blockers Identified

### 1. RBAC Blocker (Priority 0)
The devpod ServiceAccount cannot create cluster-scoped resources required for ArgoCD installation.

**Required Action:** Cluster admin must apply RBAC configuration
```bash
# Option 1: Apply the argocd-installer ClusterRole
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml

# Option 2: Grant cluster-admin directly (simpler, less granular)
kubectl create clusterrolebinding devpod-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=devpod:default
```

### 2. Namespace Blocker (Priority 0)
The `argocd` namespace does not exist and cannot be created from devpod without permissions.

**Solution:** The ARGOCD_SETUP_REQUEST.yml manifest includes namespace creation.

## Required Cluster Admin Action

To resolve this blocker, a cluster administrator must execute:

```bash
# Apply the ArgoCD installation RBAC setup
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

This manifest will:
1. Create `argocd-installer` ClusterRole with necessary permissions
2. Bind it to `devpod:default` ServiceAccount via `devpod-argocd-installer` ClusterRoleBinding
3. Create `argocd` namespace

### After RBAC is Applied

From the devpod, run the installation:

```bash
# Install ArgoCD using the local manifest
kubectl apply -n argocd -f /home/coder/Research/moltbook-org/k8s/argocd-install-manifest.yaml

# Wait for ArgoCD pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Verify installation
kubectl get pods -n argocd

# Apply Moltbook ArgoCD Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Alternative Approaches

### Option 1: External ArgoCD (Recommended)
An external ArgoCD server exists at `argocd-manager.ardenone.com`. This avoids local installation overhead.

**Implementation path:**
1. Cluster admin creates `moltbook` namespace
2. Grant devpod SA permissions to manage `moltbook` namespace
3. Create Application on external ArgoCD targeting ardenone-cluster
4. ArgoCD syncs manifests from moltbook-org repository

### Option 2: Direct kubectl Deployment
If ArgoCD is not feasible, deploy directly:

```bash
# Cluster admin creates namespace
kubectl create namespace moltbook

# Grant devpod SA permissions
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml

# Deploy all resources
kubectl apply -k k8s/
```

**Note:** This violates GitOps principles and requires manual updates.

## Existing Blocker Beads

| Bead ID | Priority | Title |
|---------|----------|-------|
| mo-21sg | P0 | CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation |
| mo-er7f | P0 | Fix: Grant cluster-admin permissions to devpod ServiceAccount |
| mo-3r0e | P0 | Architecture: Use external ArgoCD - NOT local installation |

## Verification Commands

```bash
# Check local ArgoCD namespace (should return NotFound)
kubectl get namespace argocd

# Check devpod SA permissions (should return "no")
kubectl auth can-i create customresourcedefinitions

# Check current authenticated user
kubectl auth whoami
```

## References

- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/argocd-install-manifest.yaml` - Official ArgoCD installation manifest
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide

## Next Steps

1. **CRITICAL: Cluster admin applies RBAC setup**
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
   ```

2. **Verify RBAC is applied**
   ```bash
   kubectl get clusterrole argocd-installer
   kubectl get clusterrolebinding devpod-argocd-installer
   kubectl get namespace argocd
   ```

3. **Run ArgoCD installation**
   ```bash
   kubectl apply -n argocd -f k8s/argocd-install-manifest.yaml
   ```

4. **Close bead mo-y5o after successful installation**

---

**Last Updated:** 2026-02-04 22:31 UTC
**Verified by:** mo-y5o (zai-bravo worker, GLM-4.7)
**Status:** BLOCKED - Awaiting cluster-admin action to apply ARGOCD_SETUP_REQUEST.yml

---

## Latest Update (2026-02-04 22:31 UTC)

### Completed Preparation Work
1. ✅ Downloaded official ArgoCD installation manifest (v2.13+ stable)
2. ✅ Created `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` (33,375 lines)
3. ✅ Created comprehensive `BLOCKER.md` documentation
4. ✅ Created verification script `k8s/verify-argocd-ready.sh`
5. ✅ Created blocker bead **mo-43li** (Priority 0) - "Fix: ArgoCD requires cluster-admin RBAC for installation"

### Files Ready for Installation
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - RBAC manifest (cluster-admin to apply)
- `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` - Official ArgoCD installation manifest
- `cluster-configuration/ardenone-cluster/argocd/BLOCKER.md` - Complete documentation and installation guide
- `k8s/verify-argocd-ready.sh` - Pre-installation verification script

### Installation Readiness
All preparation work is COMPLETE. The only remaining blocker is cluster-admin RBAC application.
