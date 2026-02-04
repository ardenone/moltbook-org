# RBAC Blocker: devpod-namespace-creator ClusterRoleBinding

## Status: ⚠️ BLOCKER - Requires Cluster Administrator

### Summary

The Moltbook deployment is blocked by a missing ClusterRoleBinding that must be applied by a cluster administrator. The devpod ServiceAccount does not have permission to create ClusterRole/ClusterRoleBinding resources, which are required for namespace creation and RBAC management.

### Current Status

- ❌ ClusterRole `namespace-creator` cannot be created by devpod SA
- ❌ ClusterRoleBinding `devpod-namespace-creator` cannot be created by devpod SA
- ❌ Namespace `moltbook` cannot be created by devpod SA
- ✅ All Moltbook manifests are ready and waiting

### Required Action (Cluster Admin Only)

A cluster administrator must apply the RBAC manifest:

```bash
# From the ardenone-cluster repository
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### What the Manifest Creates

The `devpod-namespace-creator-rbac.yml` manifest creates two resources:

1. **ClusterRole: namespace-creator**
   - `create`, `get`, `list`, `watch` on `namespaces`
   - `get`, `create`, `update`, `patch` on `roles`, `rolebindings`
   - `get`, `create`, `update`, `patch`, `delete` on `middlewares` (Traefik)

2. **ClusterRoleBinding: devpod-namespace-creator**
   - Binds `namespace-creator` ClusterRole to `system:serviceaccount:devpod:default`

3. **Namespace: moltbook**
   - Creates the target namespace for deployment

### Why This Requires Cluster Admin

- `ClusterRole` and `ClusterRoleBinding` are cluster-scoped resources
- Creating cluster-scoped RBAC requires `cluster-admin` privileges
- The devpod ServiceAccount only has namespace-scoped permissions
- This is a deliberate Kubernetes security boundary

### After RBAC is Applied

Once the ClusterRoleBinding is in place, the Moltbook deployment can proceed automatically:

```bash
# The devpod can then deploy everything
kubectl apply -f /home/coder/Research/moltbook-org/k8s/
```

This will deploy:
- SealedSecrets (encrypted secrets)
- PostgreSQL cluster (CloudNativePG)
- Redis cache
- moltbook-api deployment
- moltbook-frontend deployment
- Traefik IngressRoutes

### Verification

After applying the RBAC, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Check namespace exists
kubectl get namespace moltbook

# Verify devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

### Related Documentation

- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest
- `k8s/CLUSTER_ADMIN_README.md` - Detailed setup instructions
- `k8s/namespace/README.md` - RBAC configuration details

### Related Beads

- **mo-3ax**: This task (documenting and tracking the blocker)
- **mo-1njh**: Original blocker (priority 0 - critical)

---

**Last Updated**: 2026-02-04
**Status**: Awaiting cluster administrator action
**Bead**: mo-3ax
