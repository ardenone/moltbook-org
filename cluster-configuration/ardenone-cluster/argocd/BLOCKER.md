# ArgoCD Installation Blocker - ardenone-cluster

## Quick Summary
**BLOCKER**: ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount lacks cluster-admin permissions needed to install ArgoCD. A cluster-admin must apply the RBAC grant before installation can proceed.

**Resolution Path**: Cluster-admin applies `ARGOCD_SETUP_REQUEST.yml` → devpod installs ArgoCD → Moltbook Application syncs

**Verified**: 2026-02-04 22:36 UTC

**New Blocker Bead Created**: mo-2fwe (P0) - "BLOCKER: Cluster-admin must apply ArgoCD RBAC before installation"

---

## Status: BLOCKED - Requires Cluster-Admin Intervention

## Problem
ArgoCD is NOT installed in ardenone-cluster. The namespace `argocd` does not exist, preventing the Moltbook ArgoCD Application from syncing.

## Current State (Verified 2026-02-04)
- ✅ ArgoCD installation manifest prepared: `argocd-install.yml` (1,883,461 bytes, official ArgoCD v2.13+)
- ✅ RBAC request manifest prepared: `ARGOCD_SETUP_REQUEST.yml`
- ❌ `argocd` namespace does NOT exist
- ❌ ArgoCD Application CRDs exist (from Argo Rollouts), but NOT ArgoCD-specific CRDs:
  - Missing: `applications.argoproj.io` (ArgoCD Application)
  - Missing: `appprojects.argoproj.io` (ArgoCD AppProject)
  - Existing: `rollouts.argoproj.io` (from Argo Rollouts, different product)
- ❌ devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permission to:
  - Create namespaces (verified: `kubectl auth can-i create namespaces --all-namespaces` = no)
  - Create CustomResourceDefinitions (CRDs) (verified: `kubectl auth can-i create customresourcedefinitions --all-namespaces` = no)
  - Create cluster-level RBAC (ClusterRoles/ClusterRoleBindings)
  - Deploy ArgoCD components

## Existing ArgoCD-Related Infrastructure (Not Usable)
- ✅ `argocd-manager-role` ClusterRole exists (cluster-admin level permissions)
- ✅ `argocd-manager-role-binding` ClusterRoleBinding exists
- ❌ BUT: Bound to `argocd-manager` SA in `kube-system` namespace (NOT devpod's default SA)
- ❌ devpod SA cannot use this existing binding

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

## Verification Commands (Current Status)

### Check ArgoCD Namespace Status
```bash
# ❌ Result: Error from server (NotFound): namespaces "argocd" not found
kubectl get namespace argocd
```

### Check devpod SA Permissions
```bash
# ❌ Result: no (cannot create namespaces)
kubectl auth can-i create namespaces --all-namespaces

# ❌ Result: no (cannot create CRDs)
kubectl auth can-i create customresourcedefinitions --all-namespaces
```

### Check Existing Argo Infrastructure
```bash
# ✅ Argo Rollouts CRDs exist (different product from ArgoCD)
kubectl get crd | grep argoproj.io
# Output: analysisruns.argoproj.io, analysistemplates.argoproj.io,
#         experiments.argoproj.io, rollouts.argoproj.io

# ❌ ArgoCD CRDs do NOT exist
kubectl get crd | grep -E "applications\.argoproj\.io|appprojects\.argoproj\.io"
# Output: (empty)

# ❌ ArgoCD namespace does NOT exist
kubectl get pods -n argocd
# Output: No resources found in argocd namespace.
```

### Check Existing ClusterRole (Not Bound to devpod)
```bash
# ✅ ArgoCD manager role exists (full cluster-admin)
kubectl get clusterrole argocd-manager-role -o yaml
# BUT: Bound to argocd-manager SA in kube-system, NOT devpod's default SA

kubectl get clusterrolebinding argocd-manager-role-binding -o yaml
# subjects:
# - kind: ServiceAccount
#   name: argocd-manager
#   namespace: kube-system
```

## After Installation, Verify With:

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
- Bead: mo-2fwe (P0) - "BLOCKER: Cluster-admin must apply ArgoCD RBAC before installation"
- ArgoCD Application: k8s/argocd-application.yml (cannot sync without ArgoCD installed)

## ArgoCD Version
- Manifest: argoproj/argo-cd/stable (as of 2026-02-04)
- Components: API server, repo-server, application-controller, redis, notifications-controller
