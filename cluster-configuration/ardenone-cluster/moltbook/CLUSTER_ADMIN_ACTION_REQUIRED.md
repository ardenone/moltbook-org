# Cluster Admin Action Required: Moltbook Deployment RBAC Setup

## Status: 🔴 BLOCKER - Requires Cluster Administrator

### Overview

The Moltbook application deployment is **blocked** because the devpod ServiceAccount lacks permissions to create namespaces and cluster-scoped RBAC resources. This is a deliberate Kubernetes security boundary that requires cluster-admin intervention.

**This is a ONE-TIME setup action.** Once completed, future deployments will work automatically.

---

## 🚀 Quick Start (For Cluster Admins)

### Option 1: Single Command (Recommended)

```bash
# Apply RBAC + Namespace in one command
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
```

### Option 2: Two-Step Process

```bash
# Step 1: Grant devpod permission to create namespaces
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml

# Step 2: Create the moltbook namespace
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

---

## ✅ Verification

After applying the RBAC, verify success with:

```bash
# 1. Check ClusterRole exists
kubectl get clusterrole namespace-creator

# 2. Check ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# 3. Check namespace exists
kubectl get namespace moltbook

# 4. Verify devpod SA can create namespaces
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

**Expected output**: All commands should return `yes` or show the resource exists.

---

## 📋 What the Manifest Creates

### 1. ClusterRole: `namespace-creator`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-creator
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["create", "get", "list", "watch"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["get", "create", "update", "patch"]
- apiGroups: ["traefik.io"]
  resources: ["middlewares"]
  verbs: ["get", "create", "update", "patch", "delete"]
```

**Permissions granted**:
- Create and manage namespaces
- Create and manage namespace-scoped RBAC (Roles, RoleBindings)
- Manage Traefik middlewares for ingress routing

### 2. ClusterRoleBinding: `devpod-namespace-creator`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devpod-namespace-creator
subjects:
- kind: ServiceAccount
  name: default
  namespace: devpod
roleRef:
  kind: ClusterRole
  name: namespace-creator
  apiGroup: rbac.authorization.k8s.io
```

**Binds the `namespace-creator` ClusterRole to**: `system:serviceaccount:devpod:default`

### 3. Namespace: `moltbook`

Creates the `moltbook` namespace where all Moltbook resources will be deployed.

---

## 🎯 After RBAC is Applied

Once the ClusterRoleBinding is in place, the devpod can deploy Moltbook automatically:

```bash
# Deploy all Moltbook resources (from devpod)
kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
```

This will deploy:
- ✅ SealedSecrets (encrypted secrets)
- ✅ PostgreSQL cluster (CloudNativePG)
- ✅ Redis cache
- ✅ moltbook-api deployment
- ✅ moltbook-frontend deployment
- ✅ Traefik IngressRoutes

---

## 🔒 Security Considerations

### Why This Requires Cluster Admin

- `ClusterRole` and `ClusterRoleBinding` are **cluster-scoped resources**
- Creating cluster-scoped RBAC requires `cluster-admin` privileges
- The devpod ServiceAccount only has **namespace-scoped permissions**
- This is a deliberate Kubernetes security boundary

### Principle of Least Privilege

The `namespace-creator` ClusterRole follows the principle of least privilege:
- ❌ **NOT granted**: `delete` on namespaces (prevents accidental deletion)
- ❌ **NOT granted**: `update` on namespaces (prevents modification of existing namespaces)
- ❌ **NOT granted**: Access to other cluster-scoped resources (secrets, configmaps, etc.)
- ✅ **Granted**: Only `create`, `get`, `list`, `watch` on namespaces
- ✅ **Granted**: Namespace-scoped RBAC management (roles, rolebindings)
- ✅ **Granted**: Traefik middleware management for ingress configuration

---

## 📚 Related Documentation

### In This Repository

- `RBAC_BLOCKER.md` - Detailed analysis of the RBAC blocker
- `DEPLOYMENT_GUIDE.md` - Complete deployment guide
- `cluster-configuration/ardenone-cluster/moltbook/namespace/README.md` - Namespace setup documentation

### Related Beads

- **mo-11z8** (P0) - CLUSTER-ADMIN ACTION: Create moltbook namespace and RBAC for mo-3ttq
- **mo-3ttq** (P1) - Deploy: Complete Moltbook deployment to ardenone-cluster
- **mo-9ndh** (P0) - Fix: Grant namespace creation permissions to devpod ServiceAccount [CLOSED]

---

## 🆘 Troubleshooting

### Problem: `kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default` returns `no`

**Solution**: The ClusterRoleBinding was not applied correctly. Re-run:
```bash
kubectl delete clusterrolebinding devpod-namespace-creator
kubectl delete clusterrole namespace-creator
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### Problem: `kubectl get namespace moltbook` returns `NotFound`

**Solution**: The namespace was not created. Run:
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

### Problem: Still getting "permissions denied" errors after applying RBAC

**Solution**: Verify your identity has cluster-admin:
```bash
kubectl auth whoami
kubectl auth can-i create clusterrole
kubectl auth can-i create clusterrolebinding
```

If the last two commands return `no`, you do not have cluster-admin permissions. Contact your cluster administrator.

---

## 📞 Contact

For questions or issues:
- Review `RBAC_BLOCKER.md` for detailed analysis
- Check related beads for investigation history
- Contact the Moltbook team for deployment assistance

---

**Last Updated**: 2026-02-05 13:22 UTC
**Status**: 🔴 BLOCKER - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Estimated Time**: 2 minutes (one-time setup)

---

## Latest Verification Log (2026-02-05 13:22 UTC)

| Check | Status | Details |
|-------|--------|---------|
| Namespace `moltbook` | ❌ NotFound | Does not exist in cluster |
| Namespace `argocd` | ❌ NotFound | ArgoCD not installed (separate task) |
| ClusterRole `namespace-creator` | ❌ Not Installed | RBAC not applied |
| ClusterRoleBinding `devpod-namespace-creator` | ❌ Not Installed | RBAC not applied |
| Current SA namespace creation | ❌ Forbidden | `kubectl auth can-i create namespaces` returns `no` |
| k8s/ manifests | ✅ Validated | Kustomize builds successfully (24 resources) |
| Container images | ✅ Ready | `ghcr.io/ardenone/moltbook-api:latest`, `ghcr.io/ardenone/moltbook-frontend:latest` |
| SealedSecrets | ✅ Ready | All secrets encrypted and committed |

**Verified by**: mo-35ca (claude-glm-echo)
**Related bead**: mo-3bz7 (BLOCKER: Cluster-admin action - Create moltbook namespace and RBAC)

### Deployment Attempt Output

```
Error from server (Forbidden): error when creating "k8s/": namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```
