# Moltbook Deployment Blocker

## Status: BLOCKED - Cluster Admin Action Required

### Summary

The Moltbook deployment to `ardenone-cluster` is blocked because the devpod ServiceAccount lacks permissions to create namespaces and cluster-scoped RBAC resources.

### Current State

- **Namespace**: Does NOT exist (`moltbook`)
- **ClusterRole**: Does NOT exist (`namespace-creator`)
- **ClusterRoleBinding**: Does NOT exist (`devpod-namespace-creator`)
- **Devpod ServiceAccount**: Has read-only access only (via `k8s-observer-devpod-cluster-resources`)

### Root Cause

This is a chicken-and-egg problem:
1. The manifest at `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml` grants the devpod ServiceAccount permission to create namespaces
2. However, applying this manifest requires **cluster-admin** privileges
3. The current devpod:default ServiceAccount only has **read-only** access
4. Self-elevation is not possible for security reasons

### Required Action (Cluster Admin Only)

A cluster administrator must run:

```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- **ClusterRole**: `namespace-creator`
  - Permissions: create/get/list/watch namespaces
  - Permissions: create/update roles and rolebindings
  - Permissions: create/update/delete traefik middlewares
- **ClusterRoleBinding**: `devpod-namespace-creator`
  - Binds to: `system:serviceaccount:devpod:default`

### After Cluster Admin Applies RBAC

Once the RBAC is in place, deployment can proceed automatically:

```bash
# From devpod, this will work:
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

This will deploy:
- Namespace: `moltbook`
- PostgreSQL cluster (via CNPG)
- Redis deployment
- Moltbook API deployment
- Moltbook frontend deployment
- Traefik IngressRoute
- Monitoring and observability resources

### Related Beads

- **mo-20r2** (Priority 0): BLOCKER: Cluster admin must apply namespace-creator RBAC
- **mo-432** (This bead): RBAC: Apply devpod-namespace-creator ClusterRoleBinding
- **mo-saz**: Implementation: Deploy Moltbook platform to ardenone-cluster

### Architecture Notes

The devpod namespace already has a `rolebinding-controller` ServiceAccount that can:
- Create RoleBindings in existing namespaces
- Watch/list/get namespaces
- Bind specific ClusterRoles

However, it **cannot**:
- Create new namespaces
- Create ClusterRoles
- Create ClusterRoleBindings

This is by design to prevent privilege escalation from within devpods.

### Verification

After the cluster admin applies the RBAC, verify with:

```bash
# Check ClusterRole exists
kubectl get clusterrole namespace-creator

# Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Check devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default

# Should return: yes
```
