# Cluster Admin Action Required

## Bead: mo-3n94

### Summary
The Moltbook deployment requires cluster-level RBAC permissions that cannot be granted by the devpod ServiceAccount.

### Required Action
Apply the RBAC setup manifest:
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/RBAC_SETUP_REQUEST.yml
```

### What This Creates
1. **ClusterRole**: `namespace-creator` - Permissions to create namespaces and RBAC resources
2. **ClusterRoleBinding**: `devpod-namespace-creator` - Binds the ClusterRole to devpod ServiceAccount
3. **Namespace**: `moltbook` - The target namespace for the Moltbook deployment

### Verification Commands
```bash
# Verify ClusterRole exists
kubectl get clusterrole namespace-creator

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default

# Verify namespace exists
kubectl get namespace moltbook
```

### Why This Is Required
The devpod ServiceAccount cannot create ClusterRoleBindings because:
1. It would be a security vulnerability (privilege escalation)
2. Kubernetes RBAC prevents self-escalation of permissions
3. Only a cluster-admin can grant cluster-level permissions

### Next Steps (After Cluster Admin Applies RBAC)
Once the RBAC is applied, the bead workflow can continue:
1. Namespace will be created (if not exists)
2. Moltbook deployment can proceed
3. Bead mo-3n94 can be marked complete
