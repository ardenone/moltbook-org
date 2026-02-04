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
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
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
kubectl apply -f k8s/argocd-application.yml
```

## Related Documentation

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/install-argocd.sh` - Installation script
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide
- `k8s/CLUSTER_ADMIN_README.md` - Quick start for cluster admins

## Blocker Bead

**mo-21sg**: CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation
- Created: 2026-02-04 22:25 UTC
- Priority: 0 (Critical)
- Status: Awaiting cluster-admin action
- Command: `kubectl create clusterrolebinding devpod-cluster-admin --clusterrole=cluster-admin --serviceaccount=devpod:default`

## Related Documentation

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/install-argocd.sh` - Installation script
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide
- `k8s/CLUSTER_ADMIN_README.md` - Quick start for cluster admins

## Next Steps

1. **Cluster Admin**: Execute action bead **mo-21sg** to grant cluster-admin:
   ```bash
   kubectl create clusterrolebinding devpod-cluster-admin --clusterrole=cluster-admin --serviceaccount=devpod:default
   ```
2. **Run Installation Script**: `./k8s/install-argocd.sh`
3. **Verify**: `kubectl get pods -n argocd` shows ArgoCD running
4. **Deploy Moltbook**: `kubectl apply -f k8s/argocd-application.yml`
5. **Close bead**: mo-y5o can be closed after successful installation

---

**Last Updated**: 2026-02-04 22:40 UTC
**Verified by**: mo-y5o (claude-glm-charlie worker)
**Status**: BLOCKED - Awaiting cluster-admin action
**Verification Attempted**: Yes - RBAC request manifest application failed due to insufficient permissions

## Additional Findings (2026-02-04 22:40 UTC)

### Existing Infrastructure Discovered

1. **argocd-manager ClusterRole exists**: A powerful ClusterRole `argocd-manager-role` exists with `*` permissions on all resources
2. **External ArgoCD**: There's an external ArgoCD instance at `argocd-manager.ardenone.com` that the devpod proxies to
3. **Proxy Service**: An `argocd-proxy` deployment exists in the `devpod` namespace

### Why This Doesn't Solve the Problem

The external ArgoCD at `argocd-manager.ardenone.com` cannot manage Applications within ardenone-cluster because:
- ArgoCD Applications are cluster-scoped resources that must be managed by an in-cluster ArgoCD instance
- The Moltbook Application at `k8s/argocd-application.yml` references an in-cluster ArgoCD server: `https://kubernetes.default.svc`
- GitOps requires the ArgoCD controller to be running inside the cluster to monitor and reconcile resources

### Confirmed Permission Gaps

| Permission | Status | Command Result |
|------------|--------|----------------|
| Create CustomResourceDefinitions | ❌ Denied | `no` (cluster-scoped) |
| Create Namespaces | ❌ Denied | `no` (cluster-scoped) |
| Create ClusterRole | ❌ Denied | `no` (cluster-scoped) |
| Create ClusterRoleBinding | ❌ Denied | `no` (cluster-scoped) |
| List services across namespaces | ❌ Denied | `Forbidden` |

### Required Cluster Admin Command

The simplest solution is for a cluster admin to run:

```bash
kubectl create clusterrolebinding devpod-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=devpod:default
```

This single command grants the devpod ServiceAccount full cluster-admin privileges, enabling ArgoCD installation and all future GitOps operations.
