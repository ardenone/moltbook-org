# Moltbook Namespace Setup for ardenone-cluster

## Status: BLOCKER - Requires Cluster Admin

The `moltbook` namespace is required for Moltbook platform deployment but does not exist in ardenone-cluster.

## Problem

The devpod ServiceAccount lacks cluster-scoped permissions to create namespaces.

## Resolution Options

### Option 1: Cluster Admin Applies RBAC (Recommended)

A cluster administrator applies the RBAC manifest to grant namespace creation permissions to devpod:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

Then from devpod, create the namespace:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

### Option 2: Cluster Admin Creates Namespace Directly

A cluster administrator creates the namespace directly:

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

### Option 3: ArgoCD Auto-Creation (Future)

Once ArgoCD is installed in ardenone-cluster (tracked in mo-3tx), the Application manifest has `CreateNamespace=true` and will create the namespace automatically during sync.

## Files

- `moltbook-namespace.yml` - The namespace manifest
- `devpod-namespace-creator-rbac.yml` - RBAC to grant namespace creation permission
- `NAMESPACE_SETUP_REQUEST.yml` - Request manifest for cluster admin action

## Verification

```bash
# Check if namespace exists
kubectl get namespace moltbook

# Check if RBAC is applied
kubectl get clusterrolebinding devpod-namespace-creator
```

## Related Beads

- **mo-1te** - Fix: Moltbook deployment blocked by missing RBAC permissions (this documentation task)
- **mo-30c1** - Blocker: Apply ClusterRole for Moltbook namespace creation (cluster-admin action required)
- **mo-3tx** - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
- **mo-saz** - Implementation: Deploy Moltbook platform to ardenone-cluster (blocked)

## Verification from devpod

```bash
# Verify namespace does NOT exist (expected blocker)
kubectl get namespace moltbook  # Should fail with "NotFound"

# Verify RBAC is NOT applied (expected blocker)
kubectl get clusterrolebinding devpod-namespace-creator  # Should fail with "NotFound"

# Test namespace creation permission (should return "no")
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```
