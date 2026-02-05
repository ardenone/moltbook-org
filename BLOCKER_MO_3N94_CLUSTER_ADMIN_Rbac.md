# BLOCKER: mo-3n94 - Cluster Admin Action Required for RBAC Setup

## Task Summary
**Bead ID**: mo-3n94
**Title**: Admin: Apply devpod-namespace-creator ClusterRoleBinding (requires cluster-admin)
**Status**: BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)

## Problem Description
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) cannot apply cluster-level RBAC resources. This is a Kubernetes security feature that prevents privilege escalation.

Attempting to apply the RBAC manifest from devpod results in:
```
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope
```

## Current State (2026-02-05)

### Verification Results
```bash
$ kubectl get namespace moltbook
Error: Namespace does not exist

$ kubectl get clusterrolebinding devpod-namespace-creator
Error: ClusterRoleBinding does not exist

$ kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
no
```

### Resources Status
| Resource | Status | Notes |
|----------|--------|-------|
| `namespace-creator` ClusterRole | NOT EXISTS | Pending cluster-admin |
| `devpod-namespace-creator` ClusterRoleBinding | NOT EXISTS | Pending cluster-admin |
| `moltbook` Namespace | NOT EXISTS | Cannot create without RBAC |

## Required Action (Cluster-Admin Only)

A cluster administrator must run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
```

### What This Creates
1. **ClusterRole**: `namespace-creator`
   - Permissions: `create`, `get`, `list`, `watch` on `namespaces`
   - RBAC management: `create`, `get`, `update`, `patch` on `roles`, `rolebindings`
   - Traefik middleware management

2. **ClusterRoleBinding**: `devpod-namespace-creator`
   - Binds `namespace-creator` ClusterRole to `devpod:default` ServiceAccount

3. **Namespace**: `moltbook`
   - The target namespace for Moltbook deployment

## Verification Commands (After Cluster-Admin Applies)

```bash
# Verify ClusterRole exists
kubectl get clusterrole namespace-creator -o yaml

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator -o yaml

# Verify devpod SA can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default

# Verify namespace exists
kubectl get namespace moltbook
```

## Why This Is Required
1. **Security**: Kubernetes RBAC prevents self-escalation of permissions
2. **Best Practice**: Only cluster-admins should grant cluster-level permissions
3. **Principle of Least Privilege**: Devpods should not have cluster-admin by default

## Follow-Up Bead Created
**Bead mo-dsvl**: "BLOCKER: Cluster-admin required - Apply NAMESPACE_SETUP_REQUEST.yml for moltbook namespace"
- **Priority**: P0 (Critical)
- **Description**: The devpod ServiceAccount cannot apply cluster-level RBAC. A cluster administrator must run: kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
- **Status**: Open
- **Created**: 2026-02-05 12:52 UTC

## Next Steps (After Cluster-Admin Action)
1. Verify RBAC is applied using verification commands above
2. Create moltbook namespace (if not created by RBAC_SETUP_REQUEST.yml)
3. Deploy Moltbook using:
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace.yml
   kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
   ```
4. Close bead mo-3n94

## Related Files
- **Setup Manifest**: `/home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml`
- **RBAC-Only Manifest**: `/home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml`
- **Instructions**: `/home/coder/Research/moltbook-org/MOLTBOOK_RBAC_BLOCKER_STATUS.md`
- **Cluster Admin Action**: `/home/coder/Research/moltbook-org/CLUSTER_ADMIN_ACTION_REQUIRED.md` (if exists)

## Documentation References
- Moltbook deployment requires namespace creation permissions
- Traefik middleware management for ingress routes
- Role-based access control for namespace-scoped resources
