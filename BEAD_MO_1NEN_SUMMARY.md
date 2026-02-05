# Bead mo-1nen Summary: Admin: Create moltbook namespace and RBAC

**Task ID:** mo-1nen
**Title:** Admin: Create moltbook namespace and RBAC (cluster-admin required)
**Status:** BLOCKED - Requires cluster-admin action
**Date:** 2026-02-05

## Task Description

CRITICAL BLOCKER: The devpod ServiceAccount cannot create the moltbook namespace. Cluster admin must run:
```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

## Deliverables

### 1. NAMESPACE_SETUP_REQUEST.yml ✅

Location: `/home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml`

The manifest creates:
1. **ClusterRole: `namespace-creator`** - Grants namespace creation permissions
2. **ClusterRoleBinding: `devpod-namespace-creator`** - Binds to devpod ServiceAccount
3. **Namespace: `moltbook`** - The target namespace for deployment

```yaml
# Key resources defined:
- ClusterRole: namespace-creator
  - Verbs: create, get, list, watch
  - Resources: namespaces

- ClusterRoleBinding: devpod-namespace-creator
  - Subjects: system:serviceaccount:devpod:default
  - RoleRef: namespace-creator ClusterRole

- Namespace: moltbook
  - Labels: argocd.argoproj.io/managed-by: argocd
```

### 2. Documentation ✅

Complete documentation for cluster admin action:
- `k8s/CLUSTER_ADMIN_README.md` - Detailed instructions
- `CLUSTER_ADMIN_ACTION_REQUIRED.md` - Quick reference
- `NAMESPACE_CREATION_BLOCKER.md` - Full context

## Prerequisites Verified

- ✅ SealedSecret controller: INSTALLED (sealed-secrets namespace)
- ✅ CloudNativePG CRD: INSTALLED
- ✅ All manifests: READY in k8s/
- ✅ Container images: PUSHED to ghcr.io/ardenone/

## Current Cluster State

As of 2026-02-05, verified from devpod:

| Resource | Status |
|----------|--------|
| Namespace `moltbook` | ❌ Does NOT exist |
| ClusterRole `namespace-creator` | ❌ Does NOT exist |
| ClusterRoleBinding `devpod-namespace-creator` | ❌ Does NOT exist |

## Verification Commands

After cluster admin applies the manifest, verify with:

```bash
# Verify ClusterRole exists
kubectl get clusterrole namespace-creator

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default

# Verify namespace exists
kubectl get namespace moltbook
```

## After Cluster Admin Action

Once the RBAC is applied and namespace exists:

```bash
# Deploy Moltbook platform
kubectl apply -k k8s/

# Monitor deployment
kubectl get pods -n moltbook -w
```

This will deploy:
1. SealedSecrets (encrypted secrets)
2. PostgreSQL cluster (CloudNativePG)
3. Redis cache
4. moltbook-api deployment
5. moltbook-frontend deployment
6. Traefik IngressRoutes

## Related Beads

- **mo-2mws** - BLOCKER: Grant namespace creation permissions for Moltbook deployment
- **mo-3uep** - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment
- **mo-dsvl** - BLOCKER: Cluster-admin required - Apply NAMESPACE_SETUP_REQUEST.yml
- **mo-3ttq** - Deploy: Complete Moltbook deployment to ardenone-cluster (waiting for RBAC)
- **mo-s45e** - Blocker: RBAC permissions for Moltbook namespace creation (CLOSED)

## Why Cluster Admin Is Required

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) cannot create:
- ClusterRoles (cluster-scoped)
- ClusterRoleBindings (cluster-scoped)
- Namespaces (cluster-scoped)

This is an intentional Kubernetes security boundary - only cluster-admins can grant cluster-level permissions to prevent privilege escalation.

## Next Steps

1. Cluster admin applies: `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Verify namespace and RBAC are created
3. Deployment proceeds automatically with `kubectl apply -k k8s/`
