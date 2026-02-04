# Cluster Admin Action Required: Moltbook Namespace Setup

## Status: BLOCKED - Waiting for Cluster Admin

**Current State:**
- Namespace `moltbook`: **Does NOT exist**
- Blocker created: **mo-3rs** (Fix: Grant devpod namespace creation permissions or create moltbook namespace)

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
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest
- `k8s/namespace/README.md` - Detailed setup instructions
- `k8s/DEPLOYMENT_BLOCKER_MO-CX8.md` - Full blocker analysis

## Option Comparison

| Option | Namespace Created | RBAC Granted | Future Management | Best For |
|--------|------------------|--------------|-------------------|----------|
| 1 (RBAC + namespace) | ✅ | ✅ | ✅ Full namespace management | **Development** (ardenone-cluster) |
| 2 (create only) | ✅ | ❌ | ⚠️ Limited (can't recreate if deleted) | Quick testing |
| 3 (ArgoCD) | ✅ (auto) | ❌ (not needed) | ✅ Full GitOps sync | Production (requires ArgoCD installed) |

**Recommendation:**
- For ardenone-cluster (where devpods run): Use **Option 1** (RBAC + namespace) - ArgoCD is NOT installed
- For production clusters with ArgoCD: Use Option 3 (ArgoCD GitOps)
