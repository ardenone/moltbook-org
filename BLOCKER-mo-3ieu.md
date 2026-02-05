# BLOCKER: mo-3ieu - Cluster Admin Action Required

## Status: BLOCKED

This bead is blocked because it requires **cluster administrator privileges** that the current devpod ServiceAccount does not have.

## What Needs to Be Done

A cluster administrator must apply the RBAC manifest to grant the devpod ServiceAccount permission to create namespaces:

```bash
# Run this command with cluster-admin privileges
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

## What This Manifest Does

The `devpod-namespace-creator-rbac.yml` manifest creates:

1. **ClusterRole: `namespace-creator`**
   - Grants permission to create, get, list, watch namespaces
   - Grants permission to manage Roles and RoleBindings
   - Grants permission to manage Traefik Middlewares

2. **ClusterRoleBinding: `devpod-namespace-creator`**
   - Binds the `namespace-creator` ClusterRole to the `default` ServiceAccount in the `devpod` namespace

## Why This is Needed

The Moltbook deployment requires creating a new namespace (`moltbook`), but the current devpod ServiceAccount only has read-only permissions and cannot:
- Create ClusterRole or ClusterRoleBinding resources
- Create new namespaces
- Create RoleBindings in new namespaces

## After Admin Applies RBAC

Once the cluster administrator applies the RBAC manifest, the deployment can proceed with:

```bash
# Create namespace
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml

# Apply application manifests
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

## Current Permissions

The devpod ServiceAccount currently has:
- **ClusterRole: `devpod-priority-user`** - Can get/list PriorityClasses
- **ClusterRole: `mcp-k8s-observer-namespace-resources`** - Read-only access to namespace-scoped resources
- **Role: `coder-workspace-manager`** - Manage workspaces in devpod namespace

It does NOT have:
- Permission to create namespaces
- Permission to create ClusterRole/ClusterRoleBinding
- Permission to create Roles/RoleBindings in other namespaces

## Verification

To verify the RBAC is applied correctly:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

## Notes

- This is a **one-time operation** - once the RBAC is applied, future deployments can proceed without admin intervention
- ArgoCD is **not installed** on this cluster (only Argo Rollouts is installed)
- Direct kubectl apply must be used instead of ArgoCD GitOps

## Bead Reference

- Bead ID: mo-3ieu
- Title: Admin: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook deployment
- Blocking Bead: mo-272
