# Cluster Admin Action Required: mo-2i4i

## Status: BLOCKED

The devpod ServiceAccount lacks cluster-admin privileges required to apply RBAC manifests.

## Action Required

A cluster-admin must apply the following manifest:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
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

- **mo-173b**: BLOCKER: mo-2i4i requires cluster-admin to apply RBAC
- **mo-287x**: Related namespace setup
- **mo-3ttq**: Related Moltbook deployment

## Generated

2026-02-05 by claude-glm-echo (mo-2i4i)
