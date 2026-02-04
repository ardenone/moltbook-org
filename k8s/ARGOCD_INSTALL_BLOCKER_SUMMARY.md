# ArgoCD Installation Blocker Summary - ardenone-cluster

**Task**: mo-y5o - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date**: 2026-02-04 22:26 UTC
**Status**: BLOCKED - Requires cluster-admin privileges
**Action Bead**: mo-21sg (Priority 0 - Critical) - CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation

## Summary

ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the necessary cluster-admin permissions to install ArgoCD, which requires:

1. CustomResourceDefinition creation (cluster-scoped)
2. ClusterRole/ClusterRoleBinding creation (cluster-scoped)
3. Namespace creation (cluster-scoped)

## Current State

| Check | Result | Details |
|-------|--------|---------|
| argocd namespace | NotFound | `kubectl get namespace argocd` returns NotFound |
| ArgoCD CRDs | Not installed | Only Argo Rollouts CRDs exist |
| devpod permissions | Insufficient | Cannot create CRDs or cluster-scoped resources |
| RBAC application attempt | Failed | Error: User "system:serviceaccount:devpod:default" cannot create clusterroles/clusterrolebindings/namespaces |

## Solution: Cluster Admin Action Required

A cluster administrator needs to execute the following command:

```bash
# Apply the RBAC manifest that grants ArgoCD installation permissions
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

This manifest will:
1. Create `argocd-installer` ClusterRole with necessary permissions
2. Bind it to `devpod:default` ServiceAccount via `devpod-argocd-installer` ClusterRoleBinding
3. Create `argocd` namespace
4. Create `moltbook` namespace

### After RBAC is Applied

From the devpod, run:

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Apply Moltbook ArgoCD Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Verification

After installation:

```bash
# Verify ArgoCD is running
kubectl get pods -n argocd

# Verify Moltbook Application
kubectl get application moltbook -n argocd

# Verify Moltbook resources
kubectl get all -n moltbook
```

## Alternative: Direct Cluster Admin Installation

If the cluster admin prefers to install ArgoCD directly without granting RBAC:

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace moltbook

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Related Documentation

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/install-argocd.sh` - Installation script
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide
- `k8s/CLUSTER_ADMIN_README.md` - Quick start for cluster admins

## Blocker Bead

**mo-1xks**: Fix: Grant RBAC permissions to install ArgoCD in ardenone-cluster
- Created: 2026-02-04 22:25 UTC
- Priority: 0 (Critical)
- Status: Awaiting cluster-admin action

## Related Documentation

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/install-argocd.sh` - Installation script
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide
- `k8s/CLUSTER_ADMIN_README.md` - Quick start for cluster admins

## Next Steps

1. **Cluster Admin**: Execute commands from `ARGOCD_INSTALL_REQUEST.yml`
2. **Verify**: `kubectl get pods -n argocd` shows ArgoCD running
3. **Deploy Moltbook**: `kubectl apply -f k8s/argocd-application.yml`
4. **Close bead**: mo-y5o can be closed after successful installation

---

**Last Updated**: 2026-02-04 22:26 UTC
**Verified by**: mo-y5o (claude-glm-foxtrot worker)
**Status**: BLOCKED - Awaiting cluster-admin action
**Verification Attempted**: Yes - RBAC request manifest application failed due to insufficient permissions
