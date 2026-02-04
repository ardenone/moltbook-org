# ArgoCD Installation Blocker - ardenone-cluster

## Status: BLOCKED - Requires Cluster-Admin Intervention

## Problem
ArgoCD is NOT installed in ardenone-cluster. The namespace `argocd` does not exist, preventing the Moltbook ArgoCD Application from syncing.

## Current State
- ✅ ArgoCD installation manifest prepared: `argocd-install.yml` (33,375 lines)
- ✅ RBAC request manifest prepared: `ARGOCD_SETUP_REQUEST.yml`
- ❌ `argocd` namespace does NOT exist
- ❌ devpod ServiceAccount lacks permission to:
  - Create namespaces
  - Create CustomResourceDefinitions (CRDs)
  - Create cluster-level RBAC (ClusterRoles/ClusterRoleBindings)
  - Deploy ArgoCD components

## Root Cause
The current devpod ServiceAccount only has namespace-scoped permissions via `devpod-rolebinding-controller` ClusterRole, which allows:
- `get`, `list`, `watch` namespaces (read-only)
- Manage RoleBindings (but NOT ClusterRoleBindings)

ArgoCD installation requires cluster-admin level permissions for:
1. Creating the `argocd` namespace
2. Installing CRDs (Applications, AppProjects, etc.)
3. Creating ClusterRoles and ClusterRoleBindings for ArgoCD components
4. Deploying ArgoCD core components (API server, repo-server, application-controller, etc.)

## Installation Instructions (for Cluster-Admin)

### Step 1: Apply RBAC Setup Request
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

## Alternative: Direct Cluster-Admin Installation

If devpod-based installation is not preferred, a cluster-admin can install ArgoCD directly:

```bash
# From cluster-admin workstation:
kubectl create namespace argocd
kubectl apply -n argocd -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Then apply the Moltbook Application
kubectl apply -f k8s/argocd-application.yml
```

## Verification Commands

After installation, verify with:

```bash
# Check argocd namespace exists
kubectl get namespace argocd

# Check ArgoCD server is running
kubectl get deployment argocd-server -n argocd

# Check ArgoCD API is accessible
kubectl get svc argocd-server -n argocd

# List ArgoCD Applications
kubectl get applications -n argocd
```

## Files Prepared
1. **ARGOCD_SETUP_REQUEST.yml** - RBAC manifest for cluster-admin approval
2. **argocd-install.yml** - Official ArgoCD installation manifest (v2.13+ from argoproj/argo-cd/stable)
3. **BLOCKER.md** - This documentation

## Next Steps
1. **Cluster-admin must apply ARGOCD_SETUP_REQUEST.yml**
2. **Install ArgoCD using argocd-install.yml**
3. **Deploy Moltbook ArgoCD Application**
4. **Verify Moltbook syncs successfully**

## Related Issues
- Bead: mo-y5o - "CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment"
- ArgoCD Application: k8s/argocd-application.yml (cannot sync without ArgoCD installed)

## ArgoCD Version
- Manifest: argoproj/argo-cd/stable (as of 2026-02-04)
- Components: API server, repo-server, application-controller, redis, notifications-controller
