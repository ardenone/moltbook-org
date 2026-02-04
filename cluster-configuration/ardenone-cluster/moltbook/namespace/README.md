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

## Quick Start for Cluster Admins

### Option 1: Single Command (Recommended)

```bash
# Apply RBAC + Namespace in one command
kubectl apply -f NAMESPACE_SETUP_REQUEST.yml
```

### Option 2: Two-Step Process

```bash
# Step 1: Grant devpod permission to create namespaces
kubectl apply -f devpod-namespace-creator-rbac.yml

# Step 2: Create the moltbook namespace
kubectl apply -f moltbook-namespace.yml
```

## Verification

After applying, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Check namespace exists
kubectl get namespace moltbook

# Verify devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

**Expected output**: All commands should return `yes` or show the resource exists.

## After RBAC is Applied

Once the ClusterRoleBinding is in place, deploy Moltbook from the devpod:

```bash
# Option 1: Use the deployment script (recommended)
/home/coder/Research/moltbook-org/scripts/deploy-moltbook-after-rbac.sh

# Option 2: Manual deployment
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

This will deploy:
- ✅ SealedSecrets (encrypted secrets)
- ✅ PostgreSQL cluster (CloudNativePG)
- ✅ Redis cache
- ✅ moltbook-api deployment
- ✅ moltbook-frontend deployment
- ✅ Traefik IngressRoutes

## Related Documentation

- **[../CLUSTER_ADMIN_ACTION_REQUIRED.md](../CLUSTER_ADMIN_ACTION_REQUIRED.md)** - Comprehensive cluster-admin guide
- **[../README.md](../README.md)** - Moltbook cluster configuration overview
- **[../../RBAC_BLOCKER.md](../../RBAC_BLOCKER.md)** - Detailed RBAC blocker analysis
- **[../../DEPLOYMENT_GUIDE.md](../../DEPLOYMENT_GUIDE.md)** - Complete deployment guide

## Related Beads

- **mo-1te** - Fix: Moltbook deployment blocked by missing RBAC permissions (current task)
- **mo-eypj** (P0) - Cluster-admin action: Apply devpod-namespace-creator ClusterRoleBinding
- **mo-3ax** - Investigation and verification of RBAC blocker

## Verification from devpod (Pre-RBAC)

```bash
# Verify namespace does NOT exist (expected blocker)
kubectl get namespace moltbook  # Should fail with "NotFound"

# Verify RBAC is NOT applied (expected blocker)
kubectl get clusterrolebinding devpod-namespace-creator  # Should fail with "NotFound"

# Test namespace creation permission (should return "no")
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```
