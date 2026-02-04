# Namespace Creation Instructions for Moltbook Platform

## Issue Summary

The `moltbook` namespace does not exist in the `ardenone-cluster`. The devpod ServiceAccount lacks cluster-scoped permissions to create namespaces.

## Current State

- **Namespace**: `moltbook` does NOT exist
- **RBAC**: ClusterRole/ClusterRoleBinding NOT applied
- **ServiceAccount**: `system:serviceaccount:devpod:default` lacks namespace creation permissions

## Resolution Options (Choose One)

### Option 1: Create Namespace Manually (Simplest)

As a cluster administrator, run:

```bash
kubectl create namespace moltbook
```

Or apply the namespace manifest:

```bash
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

### Option 2: Grant Namespace Creation Permissions to devpod (Recommended for Future)

Apply the RBAC manifest to grant the devpod ServiceAccount permission to create namespaces:

```bash
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

This RBAC grants:
- Namespace creation/get/list/watch
- Role/RoleBinding creation in new namespaces
- Traefik Middleware creation

After applying RBAC, the devpod ServiceAccount can create the namespace:

```bash
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

### Option 3: Use NAMESPACE_REQUEST.yml (All-in-One)

```bash
kubectl apply -f k8s/NAMESPACE_REQUEST.yml
```

## Verification

After creating the namespace, verify:

```bash
kubectl get namespace moltbook
```

Expected output:
```
NAME       STATUS   AGE
moltbook   Active   <seconds>
```

## Related Beads

- **mo-1sub**: Fix: Apply RBAC for devpod namespace creation (BLOCKER)
- **mo-hv4**: Fix: Create moltbook namespace in ardenone-cluster (this task)

## Next Steps After Namespace Creation

Once the namespace exists, the full Moltbook platform can be deployed:

```bash
kubectl apply -k k8s/
```
