# Blocker Summary: mo-31tk - ClusterAdmin Required for Moltbook RBAC

**Task ID**: mo-31tk
**Status**: BLOCKER - ClusterAdmin Action Required
**Created**: 2026-02-05

## Problem

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the necessary permissions to create ClusterRole and ClusterRoleBinding resources. Applying the Moltbook namespace RBAC configuration fails with:

```
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope
```

## Required Action (Cluster Admin Only)

A cluster administrator must manually apply the following manifest:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### What This Manifest Does

The `devpod-namespace-creator-rbac.yml` manifest creates:

1. **ClusterRole: `namespace-creator`**
   - Grants permission to create, get, list, and watch namespaces
   - Grants permission to manage Roles and RoleBindings
   - Grants permission to manage Traefik middlewares

2. **ClusterRoleBinding: `devpod-namespace-creator`**
   - Binds the `namespace-creator` ClusterRole to the devpod ServiceAccount (`system:serviceaccount:devpod:default`)

## After ClusterAdmin Applies RBAC

Once the ClusterRoleBinding is applied, the Moltbook deployment can proceed:

```bash
# Step 1: Create the moltbook namespace
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml

# Step 2: Deploy Moltbook using kustomize
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

## Verification Commands

After applying the RBAC, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
```

## Related Beads

- **mo-3kwh**: BLOCKER: ClusterAdmin required - Apply devpod-namespace-creator ClusterRoleBinding
- **mo-3n94**: Previous ClusterAdmin RBAC requirement for ArgoCD setup

## Security Context

The `namespace-creator` ClusterRole grants the devpod ServiceAccount:
- Namespace creation and management
- RBAC resource creation (Roles, RoleBindings) within namespaces
- Traefik middleware management

This is scoped appropriately for namespace-level deployments without granting full cluster-admin privileges.

## Files Involved

- `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml` - RBAC manifest to be applied by ClusterAdmin
- `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml` - Namespace and Role definitions for moltbook
