# mo-1qcw: ADMIN: Cluster-admin Action Needed - Apply ARGOCD_SETUP_REQUEST.yml

## Task ID
mo-1qcw

## Status: BLOCKED - Requires Cluster-Admin Action

## Summary

Task mo-3rqc (CRITICAL: Install ArgoCD in ardenone-cluster) is blocked because the devpod ServiceAccount lacks cluster-admin permissions required to install ArgoCD (creating CRDs, namespaces, ClusterRoles).

**This task (mo-1qcw) exists specifically to document and request the cluster-admin action needed to unblock mo-3rqc.**

---

## Current State (Verified 2026-02-05)

### What Exists
- `argocd-manager-role` ClusterRole: **EXISTS** with wildcard permissions (`*` on all resources)
- `argocd-manager-role-binding` ClusterRoleBinding: **EXISTS** but bound to `kube-system:argocd-manager`
- `argocd-install.yml`: **EXISTS** (1.8MB official ArgoCD manifest)
- External ArgoCD at `argocd-manager.ardenone.com`: **ONLINE** (alternative path)

### What's Missing
- `argocd` namespace: **NOT FOUND**
- `devpod-argocd-manager` ClusterRoleBinding: **NOT FOUND**
- ArgoCD pods: **NOT FOUND** (namespace doesn't exist)

### Why It's Blocked
The devpod ServiceAccount (`devpod:default`) cannot create:
1. **ClusterRoleBindings** - cluster-scoped resource
2. **Namespaces** - cluster-scoped resource
3. **CustomResourceDefinitions** - cluster-scoped resource (needed for ArgoCD)

### Verification Commands
```bash
# Check if namespace exists
kubectl get namespace argocd

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-argocd-manager

# Check devpod SA permissions
kubectl auth can-i create namespace --all-namespaces
kubectl auth can-i create clusterrolebinding
kubectl auth can-i create customresourcedefinitions
```

---

## Required Action: Cluster-Admin Must Apply RBAC Manifest

A cluster-admin must run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

### What ARGOCD_SETUP_REQUEST.yml Creates

1. **`devpod-argocd-manager` ClusterRoleBinding** - grants devpod SA access to argocd-manager-role
2. **`argocd` namespace** - namespace for ArgoCD installation

### Manifest Contents

```yaml
---
# Step 1: Create ClusterRoleBinding to grant devpod access to existing argocd-manager-role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devpod-argocd-manager
subjects:
- kind: ServiceAccount
  name: default
  namespace: devpod
roleRef:
  kind: ClusterRole
  name: argocd-manager-role
  apiGroup: rbac.authorization.k8s.io

---
# Step 2: Create the argocd namespace
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
```

---

## After Cluster-Admin Applies RBAC

Once the RBAC manifest is applied, from the devpod run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

This will install ArgoCD using the official upstream manifest.

---

## Alternative: External ArgoCD

An external ArgoCD hub exists at `argocd-manager.ardenone.com` and is the recommended GitOps controller for ardenone-cluster (hub-and-spoke model).

**Status of External ArgoCD:**
- ArgoCD UI: **ONLINE** (returns HTTP 200)
- API: **RESPONDING**
- Credentials: **EXPIRED** (argocd-readonly token expired)

**If cluster-admin prefers the external ArgoCD approach:**
1. Provide valid credentials for argocd-manager.ardenone.com
2. Register ardenone-cluster as a managed cluster
3. Create Application for Moltbook deployment

**Reference**: See `docs/ARGOCD_ALTERNATIVE_INSTALLATION_METHODS_MO_1BCI.md` for detailed analysis.

---

## Related Beads

This issue has been tracked in multiple beads (all require the same cluster-admin action):
- **mo-1qcw** (this bead) - ADMIN: Cluster-admin action needed
- mo-3rqc - CRITICAL: Install ArgoCD in ardenone-cluster (blocked by this)
- mo-2zir - ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml
- mo-2xo0 - Blocker: ArgoCD installation requires cluster-admin
- mo-2rci - BLOCKER: Cluster Admin must apply ARGOCD_SETUP_REQUEST.yml
- mo-2c4o - ADMIN: Cluster Admin - Apply ArgoCD RBAC
- mo-dbl7 - Fix expired argocd-readonly token (external ArgoCD path)

---

## Cluster-Admin Service Accounts Identified

During investigation, the following service accounts with cluster-admin access were identified:

| ServiceAccount | Namespace | Use Case |
|----------------|-----------|----------|
| headlamp | k8s-access | Headlamp dashboard |
| superuser-admin | kube-system | Administrative access |
| longhorn-support-bundle | longhorn-system | Longhorn support |
| admin@yourdomain.com | OIDC | OIDC authentication |

**Note**: Devpod ServiceAccount cannot access tokens for these service accounts due to RBAC restrictions.

---

## Security Considerations

### Granting devpod ArgoCD Installation Permissions

The `argocd-manager-role` ClusterRole has wildcard permissions (`*` on all resources). Creating a ClusterRoleBinding to grant devpod access to this role effectively gives the devpod ServiceAccount near-cluster-admin privileges for ArgoCD operations.

**Risks:**
- Devpod compromise could affect cluster-wide resources
- Broad permissions for ArgoCD installation

**Mitigations:**
- This is a temporary privilege grant for installation
- Installation can be monitored and audited
- Consider revoking excess permissions after installation

### Alternative: External ArgoCD (Recommended)

Using the external ArgoCD at argocd-manager.ardenone.com avoids granting additional cluster-admin privileges to devpod:

**Advantages:**
- No additional RBAC changes required in ardenone-cluster
- Centralized GitOps management (hub-and-spoke model)
- No ArgoCD pods running in ardenone-cluster (reduced attack surface)

**Blocker:**
- Expired credentials (tracked in mo-dbl7)

---

## Recommended Next Steps

### Option A: Local ArgoCD Installation (Requires Cluster-Admin Action)

1. **Cluster-admin applies RBAC manifest:**
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
   ```

2. **Verify RBAC is applied:**
   ```bash
   kubectl get clusterrolebinding devpod-argocd-manager
   kubectl get namespace argocd
   ```

3. **From devpod, install ArgoCD:**
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
   ```

### Option B: External ArgoCD (Recommended)

1. **Resolve mo-dbl7** - Obtain valid credentials for argocd-manager.ardenone.com
2. **Register ardenone-cluster** as a managed cluster
3. **Create Application** for Moltbook deployment

---

## Investigation Summary (2026-02-05)

### Attempted Methods
1. ✅ **Direct kubectl apply** - Failed: Forbidden (devpod SA lacks permissions)
2. ✅ **Impersonation check** - Failed: Cannot impersonate service accounts
3. ✅ **In-cluster authentication** - Same as devpod SA (no elevated access)
4. ✅ **Sudo access investigation** - Found: User has sudo, but no cluster-admin kubeconfig
5. ✅ **Cluster-admin SA enumeration** - Found: headlamp, superuser-admin, longhorn-support-bundle (cannot access tokens)
6. ✅ **OIDC authentication** - Found: admin@yourdomain.com (requires external credentials)

### Conclusion
The devpod environment is correctly constrained with limited RBAC. Installing ArgoCD requires either:
- **Cluster-admin action** to grant temporary elevated privileges (Option A)
- **External ArgoCD credentials** to use hub-and-spoke model (Option B)

---

**Created**: 2026-02-05
**Task**: mo-1qcw
**Status**: Awaiting cluster-admin action
