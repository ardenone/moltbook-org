# RBAC Blocker: devpod-namespace-creator ClusterRoleBinding

## Status: ⚠️ BLOCKER - Requires Cluster Administrator

### Summary

The Moltbook deployment is blocked by a missing ClusterRoleBinding that must be applied by a cluster administrator. The devpod ServiceAccount does not have permission to create ClusterRole/ClusterRoleBinding resources, which are required for namespace creation and RBAC management.

### Current Status

- ❌ ClusterRole `namespace-creator` cannot be created by devpod SA
- ❌ ClusterRoleBinding `devpod-namespace-creator` cannot be created by devpod SA
- ❌ Namespace `moltbook` cannot be created by devpod SA
- ✅ All Moltbook manifests are ready and waiting

### Required Action (Cluster Admin Only)

A cluster administrator must apply the RBAC manifest:

```bash
# From the ardenone-cluster repository
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### What the Manifest Creates

The `devpod-namespace-creator-rbac.yml` manifest creates two resources:

1. **ClusterRole: namespace-creator**
   - `create`, `get`, `list`, `watch` on `namespaces`
   - `get`, `create`, `update`, `patch` on `roles`, `rolebindings`
   - `get`, `create`, `update`, `patch`, `delete` on `middlewares` (Traefik)

2. **ClusterRoleBinding: devpod-namespace-creator**
   - Binds `namespace-creator` ClusterRole to `system:serviceaccount:devpod:default`

### Why This Requires Cluster Admin

- `ClusterRole` and `ClusterRoleBinding` are cluster-scoped resources
- Creating cluster-scoped RBAC requires `cluster-admin` privileges
- The devpod ServiceAccount only has namespace-scoped permissions
- This is a deliberate Kubernetes security boundary

### After RBAC is Applied

Once the ClusterRoleBinding is in place, the Moltbook deployment can proceed automatically:

```bash
# The devpod can then deploy everything via ArgoCD or kubectl
kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
```

This will deploy:
- SealedSecrets (encrypted secrets)
- PostgreSQL cluster (CloudNativePG)
- Redis cache
- moltbook-api deployment
- moltbook-frontend deployment
- Traefik IngressRoutes

### Verification

After applying the RBAC, verify with:

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

### Related Documentation

- `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml` - RBAC manifest
- `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/` - Complete Moltbook manifests

### Related Beads

- **mo-eypj**: Current cluster-admin action bead (P0) - Blocker: Apply devpod-namespace-creator ClusterRoleBinding (created by mo-138)
- **mo-3e6j**: Previous cluster-admin action bead (P0) - BLOCKER: Cluster-admin must apply devpod RBAC for namespace creation
- **mo-39sj**: Previous cluster-admin action bead (P0) - Apply devpod-namespace-creator ClusterRoleBinding
- **mo-138**: This task - Document RBAC blocker verification for Moltbook deployment (current task)
- **mo-3ax**: Original task - Investigation and verification of RBAC blocker

### Verification Log (mo-138 - 2026-02-04 21:07 UTC)

| Check | Result | Command |
|-------|--------|---------|
| ClusterRole `namespace-creator` exists | NotFound | `kubectl get clusterrole namespace-creator` |
| ClusterRoleBinding `devpod-namespace-creator` exists | NotFound | `kubectl get clusterrolebinding devpod-namespace-creator` |
| devpod SA can create ClusterRole | Forbidden | `kubectl auth can-i create clusterrole` |
| devpod SA can create ClusterRoleBinding | Forbidden | `kubectl auth can-i create clusterrolebinding` |
| devpod SA can create namespaces | Forbidden | `kubectl auth can-i create namespaces` |
| devpod SA can impersonate for auth check | Forbidden | `kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default` |

**Conclusion from mo-138**: RBAC has NOT been applied. The blocker status is CONFIRMED. Cluster administrator action is still required.

**Note**: There are many duplicate beads tracking the same RBAC blocker. Consider consolidating:
- mo-339m, mo-2j8b, mo-12ee, mo-3kcj, mo-1c9d, mo-2ym4, mo-1k2i, mo-nohd, mo-1njh, mo-20r2, mo-1u4t, mo-1gj4, mo-h6lv, mo-1z4t, mo-3b71, mo-2bxj, mo-33lq, mo-2hgx, mo-1s5e, mo-2hoz, mo-30b6, mo-yos4 (and possibly more)

All track the same issue: Cluster admin must apply devpod-namespace-creator-rbac.yml

### Investigation Summary (mo-3ax)

**Current Context**: Working as `system:serviceaccount:devpod:default` (devpod ServiceAccount)

**Findings**:
1. ✅ devpod ServiceAccount confirmed - cannot create ClusterRole/ClusterRoleBinding (cluster-scoped resources)
2. ✅ Existing devpod ClusterRoles found:
   - `devpod-priority-user` - only PriorityClass access
   - `devpod-rolebinding-controller` - namespace get/list/watch, RoleBinding CRUD, cannot create namespaces
3. ✅ `rolebinding-controller` deployment exists in devpod namespace - manages RoleBindings only
4. ❌ ClusterRole `namespace-creator` does NOT exist
5. ❌ ClusterRoleBinding `devpod-namespace-creator` does NOT exist
6. ❌ Namespace `moltbook` does NOT exist

**Cluster Admin Access**: Only `system:masters` group has cluster-admin (no individual users with elevated access in devpod context)

**Commands Used**:
```bash
kubectl auth can-i create namespace  # Result: no
kubectl get clusterrolebinding devpod-namespace-creator  # Result: NotFound
kubectl get clusterrole namespace-creator  # Result: NotFound
kubectl get namespace moltbook  # Result: NotFound
kubectl auth whoami  # Result: system:serviceaccount:devpod:default
```

**Conclusion**: This task CANNOT be completed autonomously. A cluster administrator with `system:masters` access must manually apply the RBAC manifest. The correct action bead is **mo-39sj** (P0 - Critical).

---

### Re-verification Log (mo-138 - 2026-02-04 21:20 UTC - claude-glm-delta)

| Check | Result | Details |
|-------|--------|---------|
| Current identity | `system:serviceaccount:devpod:default` | `kubectl auth whoami` |
| ClusterRole `namespace-creator` exists | NotFound | `kubectl get clusterrole namespace-creator` |
| ClusterRoleBinding `devpod-namespace-creator` exists | NotFound | `kubectl get clusterrolebinding devpod-namespace-creator` |
| Namespace `moltbook` exists | NotFound | `kubectl get namespace moltbook` |
| Can create ClusterRole | **no** | `kubectl auth can-i create clusterrole` |
| Can create ClusterRoleBinding | **no** | `kubectl auth can-i create clusterrolebinding` |

**Conclusion from mo-138 (re-verification)**: RBAC has NOT been applied. The blocker status is CONFIRMED. Cluster administrator action is still required. Multiple duplicate beads exist tracking the same issue.

---

**Last Updated**: 2026-02-04 21:20 UTC
**Status**: CONFIRMED BLOCKER - Requires cluster administrator action
**Verified by**: mo-3ax, mo-138 (initial), mo-138 (re-verification by claude-glm-delta)
**Current Action Bead**: mo-eypj (P0 - Critical) - Apply devpod-namespace-creator ClusterRoleBinding
