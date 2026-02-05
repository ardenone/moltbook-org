# BLOCKER: mo-2i4i - CLUSTER-ACTION: Apply devpod namespace-creator RBAC for Moltbook

## Status
**BLOCKED** - Requires cluster-admin intervention

## Summary
The task was to apply RBAC permissions for the devpod ServiceAccount to create namespaces in ardenone-cluster. However, applying ClusterRole/ClusterRoleBinding resources requires cluster-admin privileges, which the devpod ServiceAccount does not have.

## What Was Attempted

### Command Executed
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### Result
```
Error from server (Forbidden): error when creating ".../devpod-namespace-creator-rbac.yml":
clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope
```

## Root Cause
This is a **bootstrap problem** (catch-22):
- The devpod ServiceAccount needs RBAC permissions to create namespaces
- But the RBAC manifest itself requires cluster-admin to apply
- The devpod ServiceAccount cannot grant itself these permissions

## RBAC Manifest Contents
The manifest creates:
1. **ClusterRole**: `namespace-creator`
   - Permissions to create/get/list/watch namespaces
   - Permissions to manage roles and rolebindings
   - Permissions to manage Traefik middlewares

2. **ClusterRoleBinding**: `devpod-namespace-creator`
   - Binds the `namespace-creator` ClusterRole to `devpod:default` ServiceAccount

## Action Required

### For Cluster Admin
A cluster-admin must manually apply the manifest:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### After RBAC is Applied
Once the cluster-admin applies the RBAC, the devpod can deploy Moltbook with:

```bash
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

## Related Beads
- **mo-3rw5** (Created): CLUSTER-ADMIN: Apply devpod namespace-creator RBAC for Moltbook (Priority 0 - Critical)
- **mo-287x**: Related namespace creation work
- **mo-3ttq**: Related Moltbook deployment work

## Related Blockers
- **BLOCKER_MO_35CA_SUMMARY.md**: Namespace 'moltbook' does not exist - requires cluster-admin
- **NAMESPACE_CREATION_BLOCKER.md**: Namespace creation requires elevated permissions
- **MOLTBOOK_RBAC_BLOCKER_STATUS.md**: Overview of RBAC blockers for Moltbook

## Verification Steps (for Cluster Admin)

After applying the RBAC, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
```

Expected output: `yes`

## Next Steps
1. Cluster-admin applies the RBAC manifest (mo-3rw5)
2. Verify RBAC is applied correctly
3. Deploy Moltbook namespace
4. Deploy Moltbook application with kustomize

## Date
2026-02-05T13:27:00Z
