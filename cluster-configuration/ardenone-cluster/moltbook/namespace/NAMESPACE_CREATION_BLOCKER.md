# Moltbook Namespace Creation Blocker

**Date**: 2026-02-05
**Bead**: mo-13e5 - Blocker: Moltbook namespace creation requires cluster-admin
**Status**: BLOCKED - Requires Cluster-Admin RBAC Approval

---

## Summary

The `moltbook` namespace does not exist in ardenone-cluster. Creation requires cluster-admin permissions which the devpod ServiceAccount currently lacks.

---

## Current State (Verified)

**Namespace Status**:
```bash
kubectl get namespace moltbook
# Error from server (NotFound): namespaces "moltbook" not found
```

**RBAC Status**:
```bash
kubectl auth can-i create namespaces --all-namespaces
# no
```

**Required RBAC**:
- `namespace-creator` ClusterRole: NOT EXISTS
- `devpod-namespace-creator` ClusterRoleBinding: NOT EXISTS

---

## Root Cause

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) only has namespace-scoped permissions via `devpod-rolebinding-controller` ClusterRole, which allows:
- `get`, `list`, `watch` namespaces (read-only)
- Manage RoleBindings (but NOT ClusterRoleBindings)

Namespace creation requires cluster-scoped permissions.

---

## Resolution Required

### Option A: Apply RBAC + Create Namespace (Recommended)

A cluster-admin must apply the RBAC setup request:

```bash
# From a cluster-admin workstation (OUTSIDE devpod):
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
1. `namespace-creator` ClusterRole with namespace creation permissions
2. `devpod-namespace-creator` ClusterRoleBinding granting devpod SA access
3. `moltbook` namespace

### Option B: Direct Namespace Creation (Quick)

A cluster-admin creates the namespace directly:

```bash
kubectl create namespace moltbook
```

### Option C: ArgoCD Sync (After ArgoCD Installation)

Once ArgoCD is installed (see `cluster-configuration/ardenone-cluster/argocd/BLOCKER.md`), the namespace will be auto-created when the Moltbook Application syncs with `CreateNamespace=true`:

```yaml
# k8s/argocd-application.yml
syncOptions:
  - CreateNamespace=true
```

---

## Files Prepared

1. **NAMESPACE_SETUP_REQUEST.yml** - Combined RBAC + namespace manifest for cluster-admin approval
2. **moltbook-namespace.yml** - Standalone namespace manifest (after RBAC is applied)
3. **devpod-namespace-creator-rbac.yml** - RBAC-only manifest

---

## Verification Commands

After RBAC is applied, verify from devpod:

```bash
# Check permissions
kubectl auth can-i create namespaces --all-namespaces
# Should return: yes

# Check namespace exists
kubectl get namespace moltbook
# Should show: NAME    STATUS   AGE
#              moltbook Active   1m
```

---

## Next Steps

1. **Cluster-admin applies NAMESPACE_SETUP_REQUEST.yml**
2. **Namespace is created automatically**
3. **Proceed with Moltbook deployment**

---

## Related Blockers

- **ArgoCD Installation**: Bead mo-y5o - ArgoCD must be installed before Application sync
- **ArgoCD RBAC**: Bead mo-2fwe - Cluster-admin must apply ArgoCD RBAC first

See `cluster-configuration/ardenone-cluster/argocd/BLOCKER.md` for ArgoCD installation status.

---

## Follow-up Bead Created

**Bead mo-1qjm** - BLOCKER: Cluster-admin must apply RBAC for moltbook namespace creation
- Priority 0 (Critical)
- Contains cluster-admin instructions for RBAC/namespace creation

---

**Last Updated**: 2026-02-05T11:42:10+00:00
**Bead**: mo-13e5
**Verified**: Namespace does not exist, devpod lacks creation permissions, ArgoCD not installed
