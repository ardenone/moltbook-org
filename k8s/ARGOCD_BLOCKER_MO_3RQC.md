# ArgoCD Installation Blocker - ardenone-cluster

**Task ID**: mo-3rqc
**Status**: BLOCKED - Requires Cluster-Admin Intervention
**Created**: 2026-02-05
**Updated**: 2026-02-05 (Verified: External ArgoCD Online, Local Installation Blocked)
**Priority**: P0 (Critical)

## Quick Summary

**BLOCKER**: ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount lacks cluster-admin permissions needed to install ArgoCD. A cluster-admin must apply the RBAC grant before installation can proceed.

**IMPORTANT**: External ArgoCD is available at `argocd-manager.ardenone.com` (health: "ok"), but the local ArgoCD Application manifest (`k8s/argocd-application.yml`) requires a LOCAL `argocd` namespace. External ArgoCD cannot create Applications in the local cluster without the CRDs being installed locally.

**Resolution Path**:
1. Cluster-admin applies `k8s/ARGOCD_INSTALL_REQUEST.yml`
2. Devpod runs installation script: `./k8s/install-argocd.sh`
3. Moltbook Application syncs via ArgoCD

## Current State (Verified 2026-02-05 01:35 UTC)

### ArgoCD Status
- **argocd namespace**: DOES NOT EXIST (verified via kubectl)
- **ArgoCD CRDs**: NOT INSTALLED (only Argo Rollouts CRDs present)
  - Missing: `applications.argoproj.io` (ArgoCD Application)
  - Missing: `appprojects.argoproj.io` (ArgoCD AppProject)
  - Existing: `rollouts.argoproj.io` (from Argo Rollouts - different product)

### RBAC Status
- **devpod SA namespace creation**: NO
- **devpod SA CRD creation**: NO
- **argocd-installer ClusterRole**: DOES NOT EXIST
- **devpod-argocd-installer ClusterRoleBinding**: DOES NOT EXIST

### What IS Ready
- ArgoCD installation manifest: `k8s/argocd-install-manifest.yaml` (1.8MB, official ArgoCD stable)
- RBAC request manifest: `k8s/ARGOCD_INSTALL_REQUEST.yml`
- Installation script: `k8s/install-argocd.sh`
- Verification script: `k8s/verify-argocd-ready.sh`
- Moltbook Application manifest: `k8s/argocd-application.yml`

### External ArgoCD Status (Reference)
- **argocd-proxy**: RUNNING in devpod namespace (47 days old, READY 1/1)
- **External endpoint**: https://argocd-manager.ardenone.com
- **Health check**: Returns "ok" (verified via curl at 2026-02-05 01:35 UTC)

**Why local ArgoCD is still needed**: The current ArgoCD Application manifest (`k8s/argocd-application.yml`) creates an Application CR in the `argocd` namespace. This requires:
1. `argocd` namespace to exist locally
2. ArgoCD CRDs (`applications.argoproj.io`, `appprojects.argoproj.io`) installed locally

While external ArgoCD exists, it cannot manage Applications without the CRDs being present in the target cluster.

## Root Cause

The devpod ServiceAccount only has namespace-scoped permissions via `devpod-rolebinding-controller`. ArgoCD installation requires cluster-admin level permissions for:

1. Creating the `argocd` namespace
2. Installing CRDs (Applications, AppProjects, ApplicationSets, etc.)
3. Creating ClusterRoles and ClusterRoleBindings for ArgoCD components
4. Deploying ArgoCD core components (API server, repo-server, application-controller, etc.)

## Cluster Admin Action Required

### Step 1: Apply RBAC Setup (30 seconds)

From a cluster-admin workstation (OUTSIDE devpod):

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

This creates:
- `argocd-installer` ClusterRole with all necessary permissions
- `devpod-argocd-installer` ClusterRoleBinding granting devpod ServiceAccount access
- `argocd` namespace
- `moltbook` namespace

### Step 2: Verify RBAC Grant

From the devpod, verify permissions are now granted:

```bash
./k8s/verify-argocd-ready.sh
```

Expected output: All checks should PASS.

### Step 3: Install ArgoCD

From the devpod (after RBAC is applied):

```bash
./k8s/install-argocd.sh
```

Or manually:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 4: Verify Installation

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check all ArgoCD components
kubectl get all -n argocd

# Verify CRDs are installed
kubectl get crd | grep argoproj.io
```

### Step 5: Deploy Moltbook Application

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# Sync the application (or wait for auto-sync)
argocd app sync moltbook --server argocd-server.argocd.svc.cluster.local
```

## Alternative: Direct Cluster-Admin Installation

If devpod-based installation is not preferred, a cluster-admin can install ArgoCD directly:

```bash
# From cluster-admin workstation:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Then apply the Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Files Prepared

1. **k8s/ARGOCD_INSTALL_REQUEST.yml** - RBAC manifest for cluster-admin approval
2. **k8s/argocd-install-manifest.yaml** - Official ArgoCD installation manifest (v2.13+)
3. **k8s/install-argocd.sh** - Installation script with verification
4. **k8s/verify-argocd-ready.sh** - Pre-installation verification script
5. **k8s/argocd-application.yml** - Moltbook Application manifest
6. **This file** - Comprehensive blocker documentation

## Related Beads

- **mo-3rqc** (this bead) - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
- **mo-1jht** (P0) - BLOCKER: Cluster-admin must apply ArgoCD RBAC before installation

## After Installation

Once ArgoCD is installed and the Moltbook Application is synced, the following will be automatically deployed:

- PostgreSQL cluster (CloudNativePG)
- Redis cache
- moltbook-api deployment
- moltbook-frontend deployment
- Traefik IngressRoutes
- SealedSecrets

## Verification Commands (Current Status)

### Check ArgoCD Namespace Status
```bash
kubectl get namespace argocd
# Expected: Error from server (NotFound)
```

### Check ArgoCD CRDs
```bash
kubectl get crd | grep -E "applications\.argoproj\.io|appprojects\.argoproj\.io"
# Expected: (empty - only Argo Rollouts CRDs exist)
```

### Check devpod SA Permissions
```bash
kubectl auth can-i create namespaces --all-namespaces
# Expected: no

kubectl auth can-i create customresourcedefinitions --all-namespaces
# Expected: no
```

## Success Criteria

This bead is complete when:
1. Cluster-admin has applied `k8s/ARGOCD_INSTALL_REQUEST.yml`
2. ArgoCD is installed and running in `argocd` namespace
3. ArgoCD CRDs are present
4. Moltbook Application is created and synced

---

**Last Updated**: 2026-02-05 01:35 UTC
**Status**: BLOCKED - Awaiting cluster-admin action
**Next Action**: Cluster-admin applies `k8s/ARGOCD_INSTALL_REQUEST.yml`

**Verification Commands Run**:
- `kubectl get namespace argocd` → NOT FOUND
- `kubectl get crd | grep argoproj.io` → Only Argo Rollouts CRDs present
- `kubectl auth can-i create namespaces` → NO (devpod SA lacks permission)
- `curl -sk https://argocd-manager.ardenone.com/healthz` → "ok" (External ArgoCD online)
- `kubectl get deployment argocd-proxy -n devpod` → READY 1/1 (proxy running)
