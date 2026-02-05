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

This blocker was originally for bead: **mo-161t**
Title: Admin: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook

Blocker beads created:
- **mo-2lv0** - BLOCKER: ClusterAdmin required - Apply devpod-namespace-creator ClusterRoleBinding for Moltbook (PRIMARY BLOCKER REFERENCE)
- **mo-1q4w** - BLOCKER: ClusterAdmin required - Apply devpod-namespace-creator ClusterRoleBinding for Moltbook
- **mo-2mi3** - Admin: Apply devpod-namespace-creator ClusterRoleBinding (attempted execution 2026-02-05 12:55 UTC - BLOCKED)
- **mo-1mjz** - BLOCKER: ClusterAdmin required - Apply devpod-namespace-creator ClusterRoleBinding for Moltbook (created 2026-02-05 12:56 UTC from mo-132r)
- **mo-132r** - Admin: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook (attempted execution 2026-02-05 12:56 UTC - BLOCKED)

## Status Update Log

### 2026-02-05 12:56 UTC - Bead mo-132r Attempt
**Result**: BLOCKED - Confirmed cluster-admin action still required

**Attempted Action**:
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

**Error Received**:
```
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope

Error from server (Forbidden): clusterrolebindings.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterrolebindings"
in API group "rbac.authorization.k8s.io" at the cluster scope
```

**Verification**:
- ClusterRole `namespace-creator`: NOT EXISTS
- ClusterRoleBinding `devpod-namespace-creator`: NOT EXISTS

**Action Taken**: Created new blocker bead **mo-1mjz** to track this cluster-admin requirement.

**Conclusion**: The RBAC resources have not yet been applied by a cluster administrator. This action requires manual intervention from a user with cluster-admin privileges.

---

### 2026-02-05 12:55 UTC - Bead mo-2mi3 Attempt
**Result**: BLOCKED - Confirmed cluster-admin action still required

**Attempted Action**:
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

**Error Received**:
```
Error from server (Forbidden): clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
in API group "rbac.authorization.k8s.io" at the cluster scope

Error from server (Forbidden): clusterrolebindings.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterrolebindings"
in API group "rbac.authorization.k8s.io" at the cluster scope
```

**Verification**:
- ClusterRole `namespace-creator`: NOT EXISTS
- ClusterRoleBinding `devpod-namespace-creator`: NOT EXISTS
- devpod SA can create namespaces: NO

**Conclusion**: The RBAC resources have not yet been applied by a cluster administrator. This action requires manual intervention from a user with cluster-admin privileges.

---

### Original Status
**BLOCKED** - Waiting for cluster-admin to apply RBAC

All beads blocked on the same cluster-admin action:
- mo-161t, mo-2mi3, mo-2lv0, mo-1q4w, mo-jima, mo-sfj9, mo-133h, mo-119y, mo-3kwh, mo-2j6u, mo-dsvl, mo-yc8c, mo-2zr2, mo-tkbd, mo-3m3k, mo-3hfy, mo-3vap, mo-b7pu, mo-3ff2, mo-1log, mo-2nwc, mo-2xo0, mo-2rci (and many duplicates)

**Required action:**
```bash
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```
