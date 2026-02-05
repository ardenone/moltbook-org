# Namespace Creation Blocker

## Problem
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permissions to create namespaces on `ardenone-cluster`. This blocks deployment of the Moltbook platform which requires a dedicated `moltbook` namespace.

## Root Cause
Creating namespaces is a cluster-level operation that requires `cluster-admin` privileges. The devpod ServiceAccount only has namespace-scoped permissions within the `devpod` namespace.

## Verification
```bash
# Check if namespace exists
kubectl get namespace moltbook
# Current status: NotFound

# Check devpod SA permissions (will fail)
kubectl create namespace moltbook
# Error: namespaces is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
```

## Solutions

### Option 1: Combined RBAC + Namespace Setup (Recommended)

A cluster administrator runs the combined setup manifest:

```bash
# Requires cluster-admin access
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

This manifest:
1. Creates the `namespace-creator` ClusterRole
2. Binds it to the devpod ServiceAccount via ClusterRoleBinding
3. Creates the `moltbook` namespace

**Pros**: One-command setup, enables future self-service namespace creation
**Cons**: Requires one-time cluster-admin action

### Option 2: Manual Namespace Creation (Quick Fix)

A cluster administrator creates only the namespace:

```bash
kubectl create namespace moltbook
```

**Pros**: Fastest, minimal RBAC changes
**Cons**: Not GitOps, manual intervention required for each namespace

### Option 3: Grant Namespace Creation Permissions (For Future Self-Service)

Apply the RBAC manifest to enable devpod to create namespaces:

```bash
# Requires cluster-admin access
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

This grants the devpod ServiceAccount permissions to:
- Create, get, list, watch namespaces
- Create and manage Roles and RoleBindings within namespaces
- Create and manage Traefik middlewares

**Pros**: Self-service namespace creation for developers
**Cons**: Requires one-time cluster-admin action

### Option 4: ArgoCD GitOps (Not Available)

The `k8s/argocd-application.yml` has `CreateNamespace=true`, but ArgoCD is not installed on `ardenone-cluster`.

**Pros**: True GitOps, self-healing
**Cons**: Requires ArgoCD installation (cluster-admin)

## Recommended Action

For immediate Moltbook deployment, use **Option 1** - apply the combined setup manifest as cluster-admin:

```bash
# Run as cluster-admin
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

After this one-time setup:
1. The `moltbook` namespace exists
2. The devpod can create additional namespaces if needed
3. Deployment can proceed with: `kubectl apply -k k8s/`

## Post-Setup Deployment Steps

Once the namespace exists and RBAC is applied:

```bash
# Deploy all resources from devpod
kubectl apply -k k8s/

# Monitor deployment
kubectl get pods -n moltbook -w
```

## Alternative: Using kustomization-no-namespace.yml

If the namespace is pre-created (Option 2), use the alternative kustomization:

```bash
# Namespace must exist first
kubectl create namespace moltbook  # Run as cluster-admin

# Then deploy from devpod using namespace-less kustomization
kubectl apply -k k8s/kustomization-no-namespace.yml
```

## Current Status
- **Namespace `moltbook`**: ❌ Not found (verified 2026-02-05)
- **devpod ServiceAccount**: ❌ Cannot create namespaces (only get/list/watch via devpod-rolebinding-controller)
- **ArgoCD**: ❌ Not installed on ardenone-cluster
- **RBAC manifest**: ✅ Ready at `k8s/namespace/devpod-namespace-creator-rbac.yml`
- **Setup manifest**: ✅ Ready at `k8s/NAMESPACE_SETUP_REQUEST.yml`
- **Documentation**: ✅ See BUILD_GUIDE.md "Deployment" section

## Action Required
- **Blocker bead created**: `mo-200h` - "BLOCKER: Cluster-admin required to apply RBAC for namespace creation"
- **Cluster-admin action needed**: Run `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`

## Related Files
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Combined RBAC + namespace setup
- `k8s/NAMESPACE_REQUEST.yml` - Namespace only (for Option 2)
- `k8s/namespace/devpod-namespace-creator-rbac.yml` - RBAC only (for Option 3)
- `k8s/namespace/moltbook-namespace.yml` - Namespace manifest
- `k8s/kustomization-no-namespace.yml` - Kustomization for pre-created namespace
- `scripts/deploy-moltbook.sh` - Full deployment script (requires cluster-admin)
- `scripts/deploy-moltbook-after-rbac.sh` - Post-RBAC deployment script
