# Moltbook RBAC Blocker Status - mo-1te

**Date**: 2026-02-04
**Bead ID**: mo-1te
**Status**: BLOCKED - Requires Cluster Admin Action
**Priority**: P0 (Critical)

## Executive Summary

The Moltbook deployment to `ardenone-cluster` is blocked due to missing RBAC permissions. The devpod ServiceAccount cannot create namespaces or apply cluster-scoped resources. This is a **chicken-and-egg problem** that requires cluster-admin intervention as a one-time setup action.

## Current State (Verified 2026-02-04)

| Resource | Status | Command |
|----------|--------|---------|
| ClusterRole `namespace-creator` | Does NOT exist | `kubectl get clusterrole namespace-creator` |
| ClusterRoleBinding `devpod-namespace-creator` | Does NOT exist | `kubectl get clusterrolebinding devpod-namespace-creator` |
| Namespace `moltbook` | Does NOT exist | `kubectl get namespace moltbook` |
| Devpod SA namespace creation permission | Denied | `kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default` |

## Root Cause

The devpod ServiceAccount only has **read-only** access to cluster-scoped resources. Creating the `namespace-creator` ClusterRole and ClusterRoleBinding requires **cluster-admin** privileges. The devpod cannot self-elevate for security reasons.

## Resolution Path

### Step 1: Cluster Admin Applies RBAC (ONE-TIME SETUP)

A cluster-admin must run one of the following commands:

**Option A: Single Command (Recommended)**
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
```

**Option B: Two-Step Process**
```bash
# Step 1: Grant devpod permission to create namespaces
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml

# Step 2: Create the moltbook namespace
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

### What the Manifest Creates

1. **ClusterRole: `namespace-creator`**
   - Permissions: create/get/list/watch namespaces
   - Permissions: create/update roles and rolebindings
   - Permissions: create/update/delete traefik middlewares

2. **ClusterRoleBinding: `devpod-namespace-creator`**
   - Binds to: `system:serviceaccount:devpod:default`

3. **Namespace: `moltbook`**
   - Labels: `argocd.argoproj.io/managed-by: argocd`

### Step 2: Verify RBAC is Applied

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

Expected output: All commands should return `yes` or show the resource exists.

### Step 3: Deploy Moltbook (After RBAC is Applied)

Once the ClusterRoleBinding is in place, the devpod can deploy Moltbook:

```bash
# Deploy all Moltbook resources (from devpod)
kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
```

This will deploy:
- SealedSecrets (encrypted secrets)
- PostgreSQL cluster (CloudNativePG)
- Redis cache
- moltbook-api deployment
- moltbook-frontend deployment
- Traefik IngressRoutes

## Security Considerations

The `namespace-creator` ClusterRole follows the principle of least privilege:
- **NOT granted**: `delete` on namespaces (prevents accidental deletion)
- **NOT granted**: `update` on namespaces (prevents modification of existing namespaces)
- **NOT granted**: Access to other cluster-scoped resources
- **Granted**: Only `create`, `get`, `list`, `watch` on namespaces
- **Granted**: Namespace-scoped RBAC management (roles, rolebindings)
- **Granted**: Traefik middleware management for ingress configuration

## Related Beads

### Active Beads (OPEN)
- **mo-xoy0** (P0) - ADMIN: Cluster Admin Action - Apply NAMESPACE_SETUP_REQUEST.yml
- **mo-30c1** (P0) - Blocker: Apply ClusterRole for Moltbook namespace creation

### Related Beads
- **mo-3ax** - Investigation and verification of RBAC blocker
- **mo-138** - RBAC blocker verification
- **mo-saz** - Implementation: Deploy Moltbook platform to ardenone-cluster

### Duplicate Beads (Consolidated into mo-xoy0)
This blocker was documented in 40+ duplicate beads that have been consolidated into mo-xoy0.

## Documentation References

- `CLUSTER_ADMIN_ACTION_REQUIRED.md` - Complete cluster admin guide
- `DEPLOYMENT_BLOCKER.md` - Detailed blocker analysis
- `RBAC_BLOCKER.md` - RBAC technical analysis
- `cluster-configuration/ardenone-cluster/moltbook/namespace/README.md` - Namespace setup docs

## Architecture Notes

The devpod namespace has a `rolebinding-controller` ServiceAccount that can:
- Create RoleBindings in existing namespaces
- Watch/list/get namespaces
- Bind specific ClusterRoles

However, it **cannot**:
- Create new namespaces
- Create ClusterRoles
- Create ClusterRoleBindings

This is by design to prevent privilege escalation from within devpods.

## Next Steps

1. **Cluster Admin**: Apply the RBAC using the commands in Step 1
2. **Verification**: Run the commands in Step 2 to confirm success
3. **Deployment**: Run the deployment command in Step 3
4. **Update Bead**: Mark mo-xoy0 as CLOSED after successful deployment

## Contact

For questions or issues:
- Review `CLUSTER_ADMIN_ACTION_REQUIRED.md` for detailed instructions
- Review `RBAC_BLOCKER.md` for technical analysis
- Contact the Moltbook team for deployment assistance

---

**Last Updated**: 2026-02-04 22:30 UTC (Updated by mo-y5o)
**Status**: 🔴 BLOCKER - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Estimated Time**: 2 minutes (one-time setup)

---

## ArgoCD Installation Blocker (mo-y5o, mo-e9cb)

In addition to namespace creation permissions, ArgoCD installation is blocked because:
1. ArgoCD is NOT installed in ardenone-cluster
2. Installing ArgoCD requires cluster-admin permissions (CRD creation, ClusterRoleBindings)

### Resolution: ArgoCD Installation

A cluster-admin should run:
```bash
# Apply RBAC and create namespaces for ArgoCD
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

After RBAC is applied, from devpod:
```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

See: `k8s/ARGOCD_INSTALL_BLOCKER_SUMMARY.md` for complete details.

---

## Verification Log (mo-1te - 2026-02-04 22:21 UTC, Updated mo-y5o - 2026-02-04 22:25 UTC)

| Check | Result | Command |
|-------|--------|---------|
| ClusterRole `namespace-creator` exists | ❌ NotFound | `kubectl get clusterrole namespace-creator` |
| ClusterRoleBinding `devpod-namespace-creator` exists | ❌ NotFound | `kubectl get clusterrolebinding devpod-namespace-creator` |
| Namespace `moltbook` exists | ❌ NotFound | `kubectl get namespace moltbook` |
| devpod SA can create namespaces | ❌ Forbidden | `kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default` |

**Conclusion from mo-1te**: RBAC has NOT been applied. The blocker status is CONFIRMED. Cluster administrator action is still required. This bead (mo-1te) consolidates the technical verification and provides the resolution path.

**Note**: This blocker has been documented in 40+ duplicate beads which have been consolidated into mo-xoy0 (P0 - ADMIN: Cluster Admin Action).

**Additional Blocker (mo-y5o)**: ArgoCD is NOT installed. Cluster admin needs to apply `k8s/ARGOCD_INSTALL_REQUEST.yml` to enable ArgoCD installation. See mo-3viq for the action bead.

---

## Verification Log Update (mo-y5o - 2026-02-04 22:30 UTC)

| Check | Result | Command |
|-------|--------|---------|
| ArgoCD namespace exists | ❌ NotFound | `kubectl get namespace argocd` |
| ArgoCD pods running | ❌ No resources | `kubectl get pods -n argocd` |
| ArgoCD CRDs installed | ❌ Only Argo Rollouts | `kubectl get crd \| grep argo` |
| Apply ARGOCD_INSTALL_REQUEST.yml | ❌ Forbidden | Cannot create clusterroles/clusterrolebindings/namespaces |

**Conclusion from mo-y5o**: ArgoCD is NOT installed. Attempted to apply ARGOCD_INSTALL_REQUEST.yml but was blocked by insufficient RBAC permissions. The action bead mo-3viq remains OPEN and requires cluster-admin execution. All preparation work is complete - only cluster-admin action is needed.
