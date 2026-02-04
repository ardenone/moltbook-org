# RBAC Blocker: devpod-namespace-creator ClusterRoleBinding

## Status: ⚠️ BLOCKER - Requires Cluster Administrator

### Summary

The Moltbook deployment is blocked by a missing ClusterRoleBinding that must be applied by a cluster administrator. The devpod ServiceAccount does not have permission to create ClusterRole/ClusterRoleBinding resources, which are required for namespace creation and RBAC management.

### What's Ready

- ✅ All Moltbook manifests created (1062 lines of YAML)
- ✅ 18 Kubernetes resources configured
- ✅ SealedSecrets generated and committed
- ✅ Kustomization configured
- ✅ ArgoCD Application manifest ready
- ✅ IngressRoute configurations for Traefik

### What's Blocked

- ❌ `devpod-namespace-creator` ClusterRole cannot be applied by devpod SA
- ❌ `devpod-namespace-creator` ClusterRoleBinding cannot be applied by devpod SA
- ❌ Moltbook namespace creation requires these RBAC resources

### Required Action (Cluster Admin Only)

Apply the RBAC manifest from a cluster-admin context:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### What the Manifest Creates

1. **ClusterRole: namespace-creator**
   - `create`, `get`, `list`, `watch` on `namespaces`
   - `get`, `create`, `update`, `patch` on `roles`, `rolebindings`
   - `get`, `create`, `update`, `patch`, `delete` on `middlewares` (Traefik)

2. **ClusterRoleBinding: devpod-namespace-creator**
   - Binds `namespace-creator` ClusterRole to `system:serviceaccount:devpod:default`

### After RBAC is Applied

Once the ClusterRoleBinding is in place, the Moltbook deployment can proceed:

```bash
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

### Related Beads

- **mo-1njh**: This blocker (priority 0 - critical)
- **mo-432**: Original task attempting to apply RBAC
- **mo-saz**: Moltbook deployment implementation

### Technical Details

The manifest is located at:
```
/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

Why this requires cluster-admin:
- `ClusterRole` and `ClusterRoleBinding` are cluster-scoped resources
- Creating cluster-scoped RBAC requires `cluster-admin` privileges
- The devpod ServiceAccount only has namespace-scoped permissions
- This is a deliberate Kubernetes security boundary

### Verification

After applying the RBAC, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

---

**Last Updated**: 2026-02-04  
**Status**: Awaiting cluster administrator action
