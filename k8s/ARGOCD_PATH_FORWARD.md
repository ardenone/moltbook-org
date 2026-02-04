# ArgoCD Path Forward - Moltbook Deployment

**Task**: mo-3tx - Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date**: 2026-02-04
**Status**: **CLARIFIED - External ArgoCD Available**

---

## Executive Summary

**Finding**: ArgoCD is **NOT installed locally** in ardenone-cluster, but an **external ArgoCD server** is available at `argocd-manager.ardenone.com` (health check returns "ok").

**Implication**: The task "Install ArgoCD in ardenone-cluster" is based on an incorrect assumption. The correct approach is to use the existing external ArgoCD.

## Architecture

```
argocd-manager.ardenone.com (External ArgoCD - Online)
    ↓ (manages multiple clusters via GitOps)
    ├── ardenone-cluster
    │   └── moltbook namespace (to be created)
    └── [other clusters]
```

## Current Status

| Component | Status | Details |
|-----------|--------|---------|
| External ArgoCD | **ONLINE** | https://argocd-manager.ardenone.com/healthz returns "ok" |
| argocd-proxy | **RUNNING** | devpod namespace (read-only proxy to external ArgoCD) |
| ArgoCD namespace | **NOT FOUND** | Local ArgoCD not installed |
| moltbook namespace | **NOT FOUND** | Namespace does not exist |
| devpod RBAC | **LIMITED** | Cannot create namespaces or CRDs |

## Recommended Path: External ArgoCD (GitOps)

### Step 1: Cluster Admin Creates Namespace

The cluster admin must create the `moltbook` namespace:

```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
- `namespace-creator` ClusterRole
- `devpod-namespace-creator` ClusterRoleBinding
- `moltbook` namespace

### Step 2: Register with External ArgoCD

Once the namespace exists, the Moltbook platform can be deployed via the external ArgoCD at `argocd-manager.ardenone.com`.

The ArgoCD Application manifest is ready at `k8s/argocd-application.yml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd  # Note: This assumes local argocd namespace
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/moltbook-org.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
```

**Note**: For external ArgoCD, the Application needs to be created via the external ArgoCD UI/API, not via kubectl.

### Step 3: Verify Deployment

```bash
# Check Moltbook pods
kubectl get pods -n moltbook

# Check IngressRoutes
kubectl get ingressroutes -n moltbook

# Expected services:
# - api-moltbook.ardenone.com
# - moltbook.ardenone.com
```

## Alternative: Direct kubectl Apply (Non-GitOps)

If ArgoCD integration is not immediately available:

```bash
# Requires cluster-admin to create namespace first
kubectl create namespace moltbook

# Apply RBAC for devpod
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml

# Deploy directly
kubectl apply -k k8s/
```

**Note**: This violates GitOps principles and requires manual updates for future changes.

## Verification

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz
# Expected: "ok"

# Check moltbook namespace (after cluster admin action)
kubectl get namespace moltbook

# Check argocd-proxy status
kubectl get deployment argocd-proxy -n devpod
```

## Files Reference

| File | Purpose |
|------|---------|
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | RBAC + namespace manifest (cluster-admin to apply) |
| `k8s/argocd-application.yml` | ArgoCD Application manifest |
| `k8s/ARGOCD_ARCHITECTURE_ANALYSIS.md` | Detailed architecture analysis |

## Blocking Beads

- mo-saz: Moltbook platform deployment
- mo-23p: Moltbook deployment verification
- All Moltbook-related beads

## Conclusion

**ArgoCD installation is NOT required locally** - the external ArgoCD at `argocd-manager.ardenone.com` should be used. The primary blocker is **namespace creation**, which requires cluster-admin intervention.

The path forward is:
1. Cluster admin applies `k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Moltbook is registered with external ArgoCD OR deployed via `kubectl apply -k k8s/`
3. Verify deployment at `moltbook.ardenone.com` and `api-moltbook.ardenone.com`
