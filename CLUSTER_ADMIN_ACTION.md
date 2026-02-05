# Cluster Admin Action Required: mo-1ob3

## Status: BLOCKED - Requiring cluster-admin action

The devpod ServiceAccount lacks cluster-admin privileges required to create the moltbook namespace and set up RBAC.

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

## Quick One-Liner Alternative

For the fastest setup, cluster-admin can run just:

```bash
kubectl create namespace moltbook
```

Then the devpod can apply the RBAC bindings afterward.

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

- **mo-1ob3**: Fix: RBAC - create moltbook namespace and ServiceAccount (this task - BLOCKED)
- **mo-3ttq**: BLOCKER: mo-3ttq requires moltbook namespace to exist
- Multiple existing blocker beads: mo-1ge8, mo-3grc, mo-3h6c, mo-2idh, mo-dtul, mo-bc16, mo-3rw5

## Verification Steps (After Cluster-Admin Action)

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Verify RBAC permissions
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default

# Verify ClusterRole exists
kubectl get clusterrole namespace-creator

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator
```

## Generated

2026-02-05 13:33 by claude-glm-alpha (mo-1ob3)
Status: BLOCKED - Awaiting cluster-admin action to create moltbook namespace
