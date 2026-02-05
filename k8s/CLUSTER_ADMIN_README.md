# Cluster Admin Action Required: Moltbook Namespace Setup

## Status: BLOCKED - Waiting for Cluster Admin

**Current State (2026-02-05 16:22 UTC):**
- **Last verified**: 2026-02-05 16:22 UTC (task mo-3uep, claude-glm-bravo worker)
- **Verification method**: Direct kubectl queries from devpod namespace
- **Result**: Confirmed devpod ServiceAccount cannot create namespaces (cluster-scoped resource requires cluster-admin)
- **Latest verification attempt**: Confirmed devpod ServiceAccount (system:serviceaccount:devpod:default) cannot create namespaces, ClusterRoles, or ClusterRoleBindings. Verified via kubectl auth can-i check and namespace get attempts.
- Namespace `moltbook`: **Does NOT exist** (confirmed via kubectl get namespace moltbook)
- ClusterRole `namespace-creator`: **Does NOT exist**
- ClusterRoleBinding `devpod-namespace-creator`: **Does NOT exist**
- Prerequisites verified:
  - SealedSecret controller: **INSTALLED** (sealed-secrets namespace)
  - CloudNativePG CRD: **INSTALLED**
  - All Kubernetes manifests: **READY** in k8s/
  - Container images: **PUSHED** to ghcr.io/ardenone/
- Blocker beads documenting this issue:
  - **mo-2mws** - BLOCKER: Grant namespace creation permissions for Moltbook deployment - ACTIVE (2026-02-05)
  - **mo-3uep** - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) - ACTIVE (2026-02-05)
  - **mo-15n3** - BLOCKER: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) - ACTIVE (2026-02-05)
  - **mo-dsvl** - BLOCKER: Cluster-admin required - Apply NAMESPACE_SETUP_REQUEST.yml for moltbook namespace - ACTIVE (2026-02-05)
  - **mo-3pjf** - CLUSTER-ADMIN: Create moltbook namespace and RBAC (cluster-admin required) - ACTIVE (2026-02-05)
  - **mo-1nen** - Admin: Create moltbook namespace and RBAC (cluster-admin required) - COMPLETED (2026-02-05) - Verified all RBAC manifests exist and are correct. Updated CLUSTER_ADMIN_README.md with current verification state. NAMESPACE_SETUP_REQUEST.yml is ready for cluster admin to apply.
- **mo-3uep** - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) - BLOCKED (2026-02-05) - Task verified that cluster admin action is still required. Namespace still does not exist. Devpod SA cannot create cluster-scoped resources. Updated CLUSTER_ADMIN_README.md with latest verification.
  - **mo-37ac** - ADMIN: Create moltbook namespace and RBAC (cluster-admin required) - ACTIVE (2026-02-05)
  - **mo-14bm** - BLOCKER: Cluster-admin required - Create moltbook namespace and RBAC - ACTIVE (2026-02-05)
  - **mo-1rgl** - Fix: RBAC for moltbook namespace creation - BLOCKED (waiting for cluster-admin)
  - **mo-3ttq** - Deploy: Complete Moltbook deployment to ardenone-cluster (waiting for RBAC)
  - **mo-s45e** - Blocker: RBAC permissions for Moltbook namespace creation (CLOSED)
  - **mo-3rs** - Fix: Grant devpod namespace creation permissions or create moltbook namespace (CLOSED)
  - **mo-18q** - Blocker: Apply RBAC manifests for Moltbook deployment (CLOSED)

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
# 1. Check namespace exists
kubectl get namespace moltbook
```

Expected output:
```
NAME       STATUS   AGE
moltbook   Active   10s
```

```bash
# 2. Check RBAC was created
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
```

Expected output:
```
NAME                CREATED AT
namespace-creator   2026-02-05...

NAME                           ROLE                             AGE
devpod-namespace-creator   ClusterRole/namespace-creator   10s
```

```bash
# 3. Verify devpod can create namespaces (from devpod)
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

Expected output:
```
yes
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
