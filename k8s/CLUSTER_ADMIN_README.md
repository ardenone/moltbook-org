# Cluster Admin Action Required: Moltbook Namespace Setup

## Status: BLOCKED - Waiting for Cluster Admin

**Current State:**
- Namespace `moltbook`: **Does NOT exist**
- Blocker beads documenting this issue:
  - **mo-s45e** - Blocker: RBAC permissions for Moltbook namespace creation (this bead)
  - **mo-3rs** - Fix: Grant devpod namespace creation permissions or create moltbook namespace
  - **mo-18q** - Blocker: Apply RBAC manifests for Moltbook deployment

## Quick Fix (30 seconds)

A cluster admin needs to run **one** of these commands:

### Option 1: Grant Namespace Creation Permissions + Create Namespace (Recommended for Development)

```bash
# From the moltbook-org directory
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

**Why this approach:**
- ArgoCD is NOT installed in ardenone-cluster
- Devpod needs namespace management permissions for future deployments
- One-time cluster admin action enables full deployment automation

### Option 1b: Apply Individual RBAC Files (Alternative to Option 1)

```bash
# From the moltbook-org directory, apply in order:
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl create namespace moltbook
kubectl apply -f k8s/namespace/moltbook-rbac.yml
```

**Why this approach:**
- Same result as Option 1, but applies files individually
- Useful if you want to review each manifest separately
- Referenced in blocker bead mo-18q

### Option 2: Create Namespace Only (Quickest, for manual deployment)

```bash
kubectl create namespace moltbook
```

### Option 3: ArgoCD GitOps Deployment (NOT AVAILABLE - requires ArgoCD installation)

```bash
# NOTE: ArgoCD is NOT installed in ardenone-cluster
# This option only works if ArgoCD is first installed
# kubectl apply -f k8s/argocd-application.yml
```

## Verification

After running the command, verify:

```bash
kubectl get namespace moltbook
```

Expected output:
```
NAME       STATUS   AGE
moltbook   Active   10s
```

## What Happens Next

Once the namespace exists, the devpod can automatically deploy:
1. SealedSecrets (encrypted secrets)
2. PostgreSQL cluster (CloudNativePG)
3. Redis cache
4. moltbook-api deployment
5. moltbook-frontend deployment
6. Traefik IngressRoutes

## Context

**Why is this blocked?**
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) does not have cluster-scoped permissions to:
- Create namespaces (cluster-scoped resource)
- Create ClusterRole/ClusterRoleBinding (cluster-scoped resources)

This is an intentional security boundary. Namespace creation requires cluster-admin privileges.

**Documentation:**
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest (RECOMMENDED)
- `k8s/namespace/devpod-namespace-creator-rbac.yml` - Individual ClusterRole/ClusterRoleBinding manifest
- `k8s/namespace/moltbook-rbac.yml` - Individual Role/RoleBinding for moltbook namespace
- `k8s/namespace/README.md` - Detailed setup instructions
- `k8s/DEPLOYMENT_BLOCKER_MO-CX8.md` - Full blocker analysis

## Option Comparison

| Option | Namespace Created | RBAC Granted | Future Management | Best For |
|--------|------------------|--------------|-------------------|----------|
| 1 (RBAC + namespace) | ✅ | ✅ | ✅ Full namespace management | **Development** (ardenone-cluster) |
| 2 (create only) | ✅ | ❌ | ⚠️ Limited (can't recreate if deleted) | Quick testing |
| 3 (ArgoCD) | ⚠️ NOT AVAILABLE | ❌ | ❌ | Requires ArgoCD installation (not present) |

**Recommendation:**
- For ardenone-cluster (where devpods run): Use **Option 1** (RBAC + namespace via NAMESPACE_SETUP_REQUEST.yml)
- Option 3 is NOT available - ArgoCD is NOT installed in ardenone-cluster
