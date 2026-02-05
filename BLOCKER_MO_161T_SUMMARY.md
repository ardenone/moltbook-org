# BLOCKER: mo-161t - ClusterAdmin Action Required

## Issue
The devpod ServiceAccount cannot create ClusterRole/ClusterRoleBinding resources at cluster scope.

## Action Required by Cluster Administrator

### Step 1: Apply RBAC Configuration
Run this command from a machine with cluster-admin privileges:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### Step 2: Verify RBAC was Applied
```bash
# Verify ClusterRole exists
kubectl get clusterrole namespace-creator

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA has namespace creation permission
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default
```

### Step 3: Proceed with Moltbook Deployment
After RBAC is applied, run these commands from the devpod:

```bash
# Create the namespace
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml

# Apply the full Moltbook deployment
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

## What This RBAC Does

The `devpod-namespace-creator-rbac.yml` manifest creates:

1. **ClusterRole: namespace-creator**
   - Permission to create, get, list, watch namespaces
   - Permission to create Roles and RoleBindings
   - Permission to manage Traefik middlewares

2. **ClusterRoleBinding: devpod-namespace-creator**
   - Binds the namespace-creator ClusterRole to the devpod ServiceAccount
   - Allows devpod to create namespaces and deploy applications

## Related Files

- RBAC manifest: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml`
- Namespace manifest: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml`
- Moltbook deployment: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`

## Bead Reference

This blocker is for bead: **mo-161t**
Title: Admin: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook
