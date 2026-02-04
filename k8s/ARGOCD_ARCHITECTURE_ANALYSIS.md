# ArgoCD Architecture Analysis for Moltbook Deployment

## Status: CLARIFIED - External ArgoCD, Not Local Installation

**Date:** 2026-02-04
**Task:** mo-3tx (CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment)

## Executive Summary

**Finding:** ArgoCD is NOT installed locally in ardenone-cluster. The architecture uses an **external ArgoCD server** at `argocd-manager.ardenone.com` to manage multiple clusters including ardenone-cluster.

**Implication:** The task "Install ArgoCD in ardenone-cluster" is based on an incorrect assumption. The correct approach is to:
1. Use the external ArgoCD server
2. Create the moltbook namespace (requires cluster-admin)
3. Register the moltbook-org repository with external ArgoCD
4. Apply the ArgoCD Application manifest

## Current Architecture

```
argocd-manager.ardenone.com (External ArgoCD)
    ↓ (manages multiple clusters)
    ├── ardenone-cluster
    │   └── [moltbook namespace - to be created]
    └── [other clusters]
```

### Components Present

| Component | Status | Location |
|-----------|--------|----------|
| External ArgoCD Server | ✅ Running | argocd-manager.ardenone.com |
| ArgoCD Health Check | ✅ HTTP 200 | https://argocd-manager.ardenone.com/healthz |
| argocd-proxy | ✅ Running | devpod namespace (read-only proxy) |
| argocd-manager-role | ✅ Present | ClusterRole (orphaned, cluster-admin) |
| argocd-manager-role-binding | ✅ Present | ClusterRoleBinding (references non-existent SA) |
| argocd-manager SA | ❌ Missing | kube-system namespace |
| ArgoCD Namespace | ❌ Missing | Does not exist |
| ArgoCD Pods | ❌ Missing | Not running locally |

### ArgoCD Proxy Details

The `argocd-proxy` deployment in the `devpod` namespace provides read-only access to the external ArgoCD:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-proxy
  namespace: devpod
spec:
  template:
    spec:
      containers:
      - name: argocd-proxy
        image: ronaldraygun/argocd-proxy:1.0.2
        env:
        - name: ARGOCD_SERVER
          value: argocd-manager.ardenone.com
        - name: ARGOCD_AUTH_TOKEN
          valueFrom:
            secretKeyRef:
              name: argocd-readonly
              key: ARGOCD_AUTH_TOKEN
```

**Status:** Token expired/invalid (auth error when querying applications)

## ArgoCD Components in Cluster

### Argo Rollouts (Installed)

```
analysisruns.argoproj.io
analysistemplates.argoproj.io
experiments.argoproj.io
rollouts.argoproj.io
```

These are **Argo Rollouts** CRDs, NOT ArgoCD. Argo Rollouts is a separate project for progressive delivery.

### Orphaned RBAC Artifacts

```yaml
# ClusterRole (cluster-admin privileges)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]

# ClusterRoleBinding (references non-existent SA)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system  # ← This SA does not exist
```

## Current Blockers

### 1. Namespace Creation (Priority 0)

The `moltbook` namespace does not exist and cannot be created from devpod due to RBAC restrictions.

**Resolution:** Apply `k8s/NAMESPACE_SETUP_REQUEST.yml` with cluster-admin access.

### 2. External ArgoCD Access (Priority 1)

The `argocd-readonly` secret token is expired. Need valid credentials to access `argocd-manager.ardenone.com`.

**Resolution:** Request fresh ArgoCD read-only token or admin credentials.

## Deployment Path Forward

### Option 1: External ArgoCD (GitOps - Recommended)

1. Cluster admin creates namespace: `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Obtain valid ArgoCD credentials for `argocd-manager.ardenone.com`
3. Create Application on external ArgoCD targeting ardenone-cluster
4. ArgoCD syncs manifests from moltbook-org repository

### Option 2: Direct kubectl apply (Non-GitOps - Temporary)

1. Cluster admin creates namespace
2. Deploy directly: `kubectl apply -k k8s/`
3. Manual maintenance (no auto-sync)

### Option 3: Install Local ArgoCD (Not Recommended)

1. Install ArgoCD in ardenone-cluster
2. Configure repository
3. Create Application

**Why not recommended:**
- Requires cluster-admin for installation
- External ArgoCD already exists and should be used
- Adds operational overhead

## Related Beads Created

- **mo-1hoi** (Priority 0): CRITICAL: Install ArgoCD in ardenone-cluster - RBAC blocker
- **mo-1ctd** (Priority 1): Alternative: Direct kubectl apply for Moltbook (bypassing ArgoCD)
- **mo-196j** (Priority 1): Research: ArgoCD architecture - external vs local

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz

# Check for local ArgoCD (should return nothing)
kubectl get pods -n argocd

# Check ArgoCD proxy
kubectl get deployment argocd-proxy -n devpod

# Check moltbook namespace (should return "not found")
kubectl get namespace moltbook
```

## References

- `k8s/CLUSTER_ADMIN_README.md` - Namespace setup instructions
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - RBAC + namespace manifest
- `k8s/argocd-application.yml` - Application manifest (for external ArgoCD)
