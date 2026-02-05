# Deployment Blocker: mo-cx8 - Namespace Creation

## Status: BLOCKED - Requires Cluster Admin

## Summary

The Moltbook platform deployment cannot proceed because the `moltbook` namespace does not exist and the current devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin permissions required to create namespaces.

## Blocker Bead

- **Bead ID**: mo-1e6t (2026-02-05) - Blocker: Apply namespace-creator ClusterRole for Moltbook deployment
- **Bead ID**: mo-3rs (previous task) - Fix: Grant devpod namespace creation permissions or create moltbook namespace
- **Bead ID**: mo-1h0s (2026-02-04) - BLOCKER: Cluster Admin - Create moltbook namespace in ardenone-cluster
- **Priority**: 0 (Critical)
- **Description**: The devpod ServiceAccount lacks permissions to create namespaces. The moltbook namespace needs to be created before deploying Moltbook platform.

## What Was Verified

1. **Namespace Status**: `moltbook` namespace does NOT exist
2. **Permissions**: Devpod ServiceAccount cannot create namespaces (checked via `kubectl auth can-i create namespaces` → NO)
3. **Manifests Ready**: All Kubernetes manifests are complete and valid in `k8s/`
4. **Kustomization**: `k8s/kustomization.yml` is properly configured

## Verification History

### mo-32c (2026-02-04)
- Confirmed `moltbook` namespace does not exist
- Confirmed devpod ServiceAccount lacks `create` verb on `namespaces` resource
- Confirmed ClusterRole `namespace-creator` does not exist
- Confirmed ClusterRoleBinding `devpod-namespace-creator` does not exist
- Verified existing `devpod-rolebinding-controller` ClusterRole only grants `get/list/watch` on namespaces
- Created blocker bead **mo-mu2k** for cluster-admin action

### mo-33lq (2026-02-04)
- Re-verified `moltbook` namespace still does not exist
- Re-verified ClusterRole `namespace-creator` still does not exist
- Re-verified ClusterRoleBinding `devpod-namespace-creator` still does not exist
- Confirmed blocker persists - RBAC must be applied by cluster admin
- Created new blocker bead **mo-33lq** tracking the RBAC application requirement

### mo-1e6t (2026-02-05)
- Verified `moltbook` namespace still does not exist
- Verified ClusterRole `namespace-creator` still does not exist
- Verified ClusterRoleBinding `devpod-namespace-creator` still does not exist
- Confirmed devpod ServiceAccount cannot create ClusterRole or ClusterRoleBinding
- Verified `NAMESPACE_SETUP_REQUEST.yml` manifest is complete and correct
- Updated documentation to reflect current verification status

## Resolution Required

A cluster administrator must perform ONE of the following:

### Option 1: ArgoCD GitOps Deployment (⭐ Recommended for Production)

```bash
# One-time setup - ArgoCD manages everything
kubectl apply -f k8s/argocd-application.yml

# ArgoCD will automatically:
# - Create the moltbook namespace (CreateNamespace=true is set)
# - Deploy all resources (database, redis, api, frontend)
# - Keep everything in sync with Git
# - Self-heal if resources are modified
```

**Why ArgoCD is preferred:**
- GitOps native - no RBAC sprawl
- Self-healing - automatically fixes drift
- No manual intervention needed after initial setup
- Rollback support with Git history

### Option 2: Direct Namespace Creation (Quickest for Manual Deploy)

```bash
# Create only the namespace (devpod can deploy into existing namespaces)
kubectl create namespace moltbook
```

### Option 3: RBAC + Namespace (For Development Environment)

```bash
# From a terminal with cluster-admin access
cd /home/coder/Research/moltbook-org
./k8s/setup-namespace.sh
```

### Option 4: Manual kubectl Apply

```bash
# Apply the consolidated setup manifest
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

## What Each Option Does

| Option | Namespace Created | RBAC Granted | Future Management | Best For |
|--------|------------------|--------------|-------------------|----------|
| 1 (ArgoCD) | ✅ | ❌ | ✅ GitOps + Self-healing | Production |
| 2 (create only) | ✅ | ❌ | ⚠️ Limited (manual deploy) | Quick testing |
| 3 (RBAC + namespace) | ✅ | ✅ | ✅ Full namespace management | Development |
| 4 (kubectl apply) | ✅ | ✅ | ✅ Full namespace management | Development |

## After Resolution

Once the namespace exists, deployment proceeds automatically:

```bash
# From the devpod
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

This will deploy:
1. SealedSecrets (encrypted secrets)
2. PostgreSQL cluster (CloudNativePG)
3. Redis cache
4. moltbook-api deployment
5. moltbook-frontend deployment
6. Traefik IngressRoutes

## Files Reference

- `k8s/CLUSTER_ADMIN_README.md` - **Quick start guide for cluster admins** (START HERE)
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest
- `k8s/setup-namespace.sh` - Automated setup script
- `k8s/namespace/README.md` - Detailed setup instructions
- `k8s/kustomization.yml` - Main deployment manifest
