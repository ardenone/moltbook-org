# RBAC Application Guide for Moltbook Deployment

**Status:** BLOCKER - Cluster Admin Action Required
**Date:** 2026-02-04
**Related Beads:**
- **mo-s45e** - Blocker: RBAC permissions for Moltbook namespace creation (current)
- **mo-18q** - Blocker: Apply RBAC manifests for Moltbook deployment

## Overview

This guide provides step-by-step instructions for cluster administrators to apply the required RBAC manifests for Moltbook deployment in ardenone-cluster.

## Current State

| Component | Status | Notes |
|-----------|--------|-------|
| `moltbook` namespace | ❌ Does NOT exist | Cannot create without cluster-admin |
| `namespace-creator` ClusterRole | ❌ Does NOT exist | Requires cluster-admin to create |
| `devpod-namespace-creator` ClusterRoleBinding | ❌ Does NOT exist | Requires cluster-admin to create |
| `moltbook-deployer` Role | ⏸️ Pending | Requires namespace to exist first |
| `moltbook-deployer-binding` RoleBinding | ⏸️ Pending | Requires namespace to exist first |

## Why This is Blocked

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-scoped permissions to:
1. **Create namespaces** (cluster-scoped resource)
2. **Create ClusterRole/ClusterRoleBinding** (cluster-scoped resources)

This is an **intentional security boundary**. Namespace creation requires cluster-admin privileges.

---

## Quick Start (Recommended Path)

### Option 1: Apply Consolidated Setup (1 Command)

This is the **simplest approach** - one manifest handles everything:

```bash
# From the moltbook-org directory
cd /home/coder/Research/moltbook-org
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

**What this does:**
1. Creates `namespace-creator` ClusterRole (grants namespace creation permissions)
2. Creates `devpod-namespace-creator` ClusterRoleBinding (binds to devpod ServiceAccount)
3. Creates `moltbook` namespace

**After this completes:**
```bash
# Verify namespace exists
kubectl get namespace moltbook

# Apply namespace-scoped RBAC
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

---

## Detailed Step-by-Step Instructions

### Step 1: Apply Cluster-Level RBAC

**Manifest:** `k8s/namespace/devpod-namespace-creator-rbac.yml`

```bash
# Apply the ClusterRole and ClusterRoleBinding
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

**Expected output:**
```
clusterrole.rbac.authorization.k8s.io/namespace-creator created
clusterrolebinding.rbac.authorization.k8s.io/devpod-namespace-creator created
```

**What this grants:**
- `create`, `get`, `list`, `watch` on `namespaces` resources
- `get`, `create`, `update`, `patch` on `roles` and `rolebindings`
- `get`, `create`, `update`, `patch`, `delete` on Traefik `middlewares`

**Verification:**
```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod ServiceAccount can now check namespace permissions
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
# Should return: yes
```

---

### Step 2: Create the Moltbook Namespace

**Manifest:** `k8s/namespace/moltbook-namespace.yml`

```bash
# Create the namespace
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

**Expected output:**
```
namespace/moltbook created
```

**What this creates:**
- Namespace `moltbook` with labels for ArgoCD management

**Verification:**
```bash
# Check namespace exists
kubectl get namespace moltbook

# Expected output:
# NAME       STATUS   AGE
# moltbook   Active   10s
```

---

### Step 3: Apply Namespace-Scoped RBAC

**Manifest:** `k8s/namespace/moltbook-rbac.yml`

**IMPORTANT:** This step requires the namespace to exist first (from Step 2).

```bash
# Apply Role and RoleBinding for moltbook namespace
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

**Expected output:**
```
role.rbac.authorization.k8s.io/moltbook-deployer created
rolebinding.rbac.authorization.k8s.io/moltbook-deployer-binding created
```

**What this grants:**
- Full CRUD on `configmaps`, `secrets`, `sealedsecrets`
- Full CRUD on `deployments`, `replicasets`, `services`
- Full CRUD on CNPG `clusters`, `backups`, `scheduledbackups`
- Full CRUD on Traefik `ingressroutes`, `middlewares`
- Read-only access to `pods`, `pods/log`, `events`

**Verification:**
```bash
# Check Role exists
kubectl get role -n moltbook moltbook-deployer

# Check RoleBinding exists
kubectl get rolebinding -n moltbook moltbook-deployer-binding

# Verify devpod can create deployments in moltbook
kubectl auth can-i create deployments --as=system:serviceaccount:devpod:default -n moltbook
# Should return: yes
```

---

## All-in-One Command (Alternative)

If you prefer to apply all manifests individually:

```bash
# From the moltbook-org directory
cd /home/coder/Research/moltbook-org

# Apply all manifests in order
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/namespace/moltbook-namespace.yml
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

---

## Verification Checklist

After applying the RBAC manifests, verify the setup:

```bash
# 1. Check cluster-level RBAC
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator

# 2. Check namespace exists
kubectl get namespace moltbook

# 3. Check namespace-level RBAC
kubectl get role -n moltbook moltbook-deployer
kubectl get rolebinding -n moltbook moltbook-deployer-binding

# 4. Verify devpod permissions
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
kubectl auth can-i create deployments --as=system:serviceaccount:devpod:default -n moltbook
kubectl auth can-i create sealedsecrets --as=system:serviceaccount:devpod:default -n moltbook

# All commands should return: yes
```

---

## What Happens Next

Once the RBAC is applied and the namespace exists, the devpod can deploy:

1. ✅ SealedSecrets (encrypted secrets)
2. ✅ PostgreSQL cluster (CloudNativePG)
3. ✅ Redis cache
4. ✅ moltbook-api deployment
5. ✅ moltbook-frontend deployment
6. ✅ Traefik IngressRoutes

**Deployment command (run from devpod):**
```bash
# Apply all Moltbook manifests
kubectl apply -k k8s/
```

---

## Troubleshooting

### Error: "namespaces is forbidden"

**Problem:** Cluster-level RBAC not applied yet.

**Solution:** Run Step 1 (apply `devpod-namespace-creator-rbac.yml`)

### Error: "namespace 'moltbook' not found"

**Problem:** Namespace doesn't exist yet.

**Solution:** Run Step 2 (apply `moltbook-namespace.yml` or `NAMESPACE_SETUP_REQUEST.yml`)

### Error: "cannot create role in namespace 'moltbook'"

**Problem:** Trying to apply namespace-scoped RBAC before namespace exists.

**Solution:** Create the namespace first (Step 2), then apply RBAC (Step 3)

### Verification Command Returns "no"

**Problem:** RBAC not properly bound to devpod ServiceAccount.

**Solution:**
1. Check ServiceAccount exists: `kubectl get sa -n devpod default`
2. Check ClusterRoleBinding subjects match ServiceAccount
3. Re-apply the RBAC manifest

---

## Security Considerations

### Granted Permissions

**Cluster-level (namespace-creator):**
- ⚠️ Can create namespaces (cluster-scoped)
- ✅ Can manage roles/rolebindings within namespaces
- ✅ Can manage Traefik middlewares

**Namespace-level (moltbook-deployer):**
- ✅ Full CRUD on all Moltbook resources (within moltbook namespace only)
- ✅ Cannot affect other namespaces
- ✅ No cluster-level permissions

### Security Audit

To audit what permissions the devpod ServiceAccount has:

```bash
# View all permissions for devpod:default
kubectl auth can-i --list --as=system:serviceaccount:devpod:default

# View permissions in moltbook namespace
kubectl auth can-i --list --as=system:serviceaccount:devpod:default -n moltbook
```

### Revoking Permissions

If you need to revoke these permissions later:

```bash
# Remove cluster-level permissions
kubectl delete clusterrolebinding devpod-namespace-creator
kubectl delete clusterrole namespace-creator

# Remove namespace-level permissions
kubectl delete rolebinding -n moltbook moltbook-deployer-binding
kubectl delete role -n moltbook moltbook-deployer
```

---

## Alternative Approaches

### Option 1: Namespace Only (Minimal)

If you don't want to grant devpod namespace creation permissions:

```bash
# Create namespace manually as cluster-admin
kubectl create namespace moltbook

# Then apply namespace-scoped RBAC from devpod
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

**Pros:** Least privilege
**Cons:** Devpod cannot recreate namespace if deleted, cannot create new namespaces

### Option 2: Direct Deployment (No RBAC)

If you prefer cluster admin to deploy everything:

```bash
# Create namespace
kubectl create namespace moltbook

# Deploy all resources as cluster-admin
kubectl apply -k k8s/
```

**Pros:** No RBAC management
**Cons:** Not GitOps, requires cluster admin for all updates

---

## Related Documentation

- `k8s/namespace/README.md` - Namespace setup overview
- `k8s/CLUSTER_ADMIN_README.md` - Quick start guide
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated setup manifest
- `k8s/DEPLOYMENT_BLOCKER.md` - Full deployment blocker analysis

---

## Summary

**For Cluster Administrators:**

1. **Quick Path:** Run `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml` (one command)
2. **Verification:** Run the verification checklist above
3. **Done:** The devpod can now deploy Moltbook independently

**Estimated Time:** 2 minutes

**Impact:** Unblocks Moltbook deployment completely
