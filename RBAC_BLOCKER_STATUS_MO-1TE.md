# RBAC Blocker Status - Bead mo-1te

## Summary

The Moltbook deployment is blocked due to missing RBAC permissions. The devpod ServiceAccount cannot create namespaces, and the `namespace-creator` ClusterRole that would grant this permission requires cluster-admin privileges to apply.

## Current State (2026-02-04)

| Resource | Status |
|----------|--------|
| `moltbook` namespace | ❌ Does NOT exist |
| `namespace-creator` ClusterRole | ❌ NOT applied |
| `devpod-namespace-creator` ClusterRoleBinding | ❌ NOT applied |
| Devpod ServiceAccount namespace permissions | ❌ Forbidden |

## Error Evidence

```
# Attempting to apply ClusterRole as devpod ServiceAccount:
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope

# Attempting to create namespace:
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```

## Existing ClusterRoles

Only these devpod-related ClusterRoles exist:
- `devpod-priority-user`
- `devpod-rolebinding-controller`

The `namespace-creator` ClusterRole is **missing**.

## Required Action (Cluster Admin Only)

A cluster-admin must apply:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

This manifest creates:
1. **ClusterRole**: `namespace-creator` - Grants create/get/list/watch on namespaces
2. **ClusterRoleBinding**: `devpod-namespace-creator` - Binds the role to devpod ServiceAccount

## After RBAC is Applied

Once a cluster-admin applies the RBAC manifest, deploy Moltbook with:

```bash
kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
```

## Blocker Bead Created

- **Bead ID**: mo-1pwp
- **Title**: Blocker: RBAC - Cluster admin must apply namespace-creator ClusterRole
- **Priority**: 0 (Critical)

## Related Files

- RBAC manifest: `cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml`
- Namespace manifest: `cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml`
- Kustomize root: `cluster-configuration/ardenone-cluster/moltbook/kustomization.yml`
