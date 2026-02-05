# BLOCKER: mo-1ob3 - Namespace Creation Requires Cluster-Admin

## Bead ID
**mo-1ob3**: "Fix: RBAC - create moltbook namespace and ServiceAccount"

## Status
**BLOCKED** - Requires cluster-admin intervention

## Problem
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permission to create namespaces on `ardenone-cluster`. The `moltbook` namespace does not exist and cannot be created by the devpod.

## Verification
```bash
# Namespace does not exist
kubectl get namespace moltbook
# Error: NotFound

# Devpod SA cannot create namespaces
kubectl auth can-i create namespaces
# Error: no

# Devpod SA only has get/list/watch on namespaces (via devpod-rolebinding-controller)
```

## Current RBAC Permissions
The devpod ServiceAccount has:
- `devpod-rolebinding-controller`: get, list, watch on namespaces (NOT create)
- `mcp-k8s-observer-cluster-resources`: read-only access to cluster resources

## Required Action
A cluster-admin must apply the combined setup manifest:

```bash
# Run as cluster-admin
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This manifest creates:
1. **ClusterRole**: `namespace-creator`
   - Permissions to create, get, list, watch namespaces
   - Permissions to create/update roles and rolebindings
   - Permissions to manage Traefik middlewares

2. **ClusterRoleBinding**: `devpod-namespace-creator`
   - Binds the `namespace-creator` ClusterRole to `devpod:default` ServiceAccount

3. **Namespace**: `moltbook`
   - Creates the required namespace for Moltbook deployment

## After Cluster-Admin Action
Once the cluster-admin applies the manifest:

1. The `moltbook` namespace will exist
2. The devpod can create additional namespaces if needed
3. Task mo-1ob3 can proceed with applying RBAC configurations:
   ```bash
   kubectl apply -f k8s/namespace/moltbook-rbac.yml
   ```

## Alternative Options

### Option 1: Namespace Only (Quick Fix)
```bash
# Run as cluster-admin
kubectl create namespace moltbook
```
Then apply RBAC from devpod.

### Option 2: ArgoCD GitOps (Not Available)
The `k8s/argocd-application.yml` has `CreateNamespace=true`, but ArgoCD is not installed on `ardenone-cluster`.

## Related Blocker Beads
- **mo-3grc**: "BLOCKER: Cluster-admin required to create moltbook namespace and RBAC" (just created)

## Related Documentation
- `NAMESPACE_CREATION_BLOCKER.md` - Detailed analysis of namespace creation blockers
- `CLUSTER_ADMIN_ACTION.md` - Previous cluster-admin action request for mo-2i4i
- `MOLTBOOK_RBAC_BLOCKER_STATUS.md` - Overall RBAC blocker status

## Files Ready for Deployment
Once namespace exists:
- `k8s/namespace/moltbook-rbac.yml` - RBAC for devpod to manage moltbook resources
- `k8s/kustomization.yml` - Full deployment manifest
- `k8s/kustomization-no-namespace.yml` - Alternative kustomization for pre-created namespace

## Next Steps (After Cluster-Admin Action)
1. Verify namespace exists: `kubectl get namespace moltbook`
2. Apply RBAC: `kubectl apply -f k8s/namespace/moltbook-rbac.yml`
3. Deploy resources: `kubectl apply -k k8s/`
4. Monitor deployment: `kubectl get pods -n moltbook -w`

---
**Generated**: 2026-02-05 by claude-glm-bravo (mo-1ob3)
**Status**: BLOCKED - Awaiting cluster-admin action
