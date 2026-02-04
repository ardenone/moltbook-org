# ArgoCD Installation Blocker - ardenone-cluster

**Task**: mo-3tx - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date**: 2026-02-04 21:51 UTC
**Status**: BLOCKED - Requires cluster-admin privileges
**Action Bead**: mo-3viq (Priority 0 - Critical)

## Summary

ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount lacks permissions to install ArgoCD (requires cluster-admin for CRD creation and namespace setup).

## Current State Verification

| Check | Result | Details |
|-------|--------|---------|
| argocd namespace | NotFound | `kubectl get namespace argocd` |
| ArgoCD CRDs | Not installed | Only Argo Rollouts CRDs exist (rollouts.argoproj.io, etc.) |
| argocd-installer ClusterRole | NotFound | `kubectl get clusterrole argocd-installer` |
| devpod-argocd-installer ClusterRoleBinding | NotFound | `kubectl get clusterrolebinding devpod-argocd-installer` |
| Current identity | `system:serviceaccount:devpod:default` | `kubectl auth whoami` |

## Required Actions

### Cluster Admin (mo-3viq - Priority 0)

```bash
# Step 1: Apply RBAC and create namespaces
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml

# Step 2: Verify RBAC was applied
kubectl get clusterrole argocd-installer
kubectl get clusterrolebinding devpod-argocd-installer
kubectl get namespace argocd
kubectl get namespace moltbook

# Step 3: Install ArgoCD (can be done from devpod after RBAC)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 4: Verify ArgoCD pods are running
kubectl get pods -n argocd

# Step 5: Apply Moltbook ArgoCD Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# Step 6: Verify Moltbook deployment
kubectl get application moltbook -n argocd
kubectl get all -n moltbook
```

### After ArgoCD is Installed

- ArgoCD will automatically sync the Moltbook platform
- Namespace `moltbook` will be created automatically (CreateNamespace=true)
- All resources (PostgreSQL, Redis, API, Frontend) will be deployed

## Blocking Beads

The following beads are blocked until ArgoCD is installed:
- **mo-saz** (P0): Moltbook platform deployment to ardenone-cluster
- **mo-23p** (P0): Related Moltbook deployment tasks

## Files Created/Updated

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin to apply
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Complete installation guide (updated with verification)
- `k8s/argocd-application.yml` - ArgoCD Application manifest (ready to apply)

## Related Documentation

- `ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation steps
- `RBAC_BLOCKER.md` - Namespace creation RBAC blocker (separate issue)
- `DEPLOYMENT_BLOCKER.md` - Overall deployment blocker analysis

## Next Steps

1. Cluster-admin executes bead **mo-3viq** with commands above
2. ArgoCD installation verified: `kubectl get pods -n argocd`
3. Moltbook ArgoCD Application applied: `kubectl apply -f k8s/argocd-application.yml`
4. Bead mo-saz can proceed with platform deployment
5. Bead mo-3tx can be closed (documentation complete, action bead created)

---

**Last Updated**: 2026-02-04 21:51 UTC
**Verified by**: mo-3tx (zai-bravo worker)
**Status**: BLOCKED - Awaiting cluster-admin action
