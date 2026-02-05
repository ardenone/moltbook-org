# Cluster Admin Action Required: mo-1ob3

## Status: BLOCKED

The devpod ServiceAccount lacks cluster-admin privileges required to create the moltbook namespace.

## Action Required

A cluster-admin must apply the following manifest:

```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

Or alternatively:

```bash
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

## What This Manifest Does

Creates the following RBAC resources:

1. **ClusterRole**: `namespace-creator`
   - Permissions to create, get, list, watch namespaces
   - Permissions to create/update roles and rolebindings
   - Permissions to manage Traefik middlewares

2. **ClusterRoleBinding**: `devpod-namespace-creator`
   - Binds the `namespace-creator` ClusterRole to the `devpod:default` ServiceAccount

## Error Encountered

```
Error from server (Forbidden): User "system:serviceaccount:devpod:default" cannot create resource "clusterroles" in API group "rbac.authorization.k8s.io" at the cluster scope
Error from server (Forbidden): User "system:serviceaccount:devpod:default" cannot create resource "clusterrolebindings" in API group "rbac.authorization.k8s.io" at the cluster scope
```

## After Applying This RBAC

Once a cluster-admin applies this manifest, the devpod can deploy Moltbook with:

```bash
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

## Related Beads

- **mo-3h6c**: Fix: RBAC - cluster-admin must apply namespace-creator RBAC (this blocker)
- **mo-3ttq**: BLOCKER: mo-3ttq requires moltbook namespace to exist
- **mo-1ob3**: Fix: RBAC - create moltbook namespace and ServiceAccount (this task)

## Generated

2026-02-05 by claude-glm-echo (mo-1ob3)
