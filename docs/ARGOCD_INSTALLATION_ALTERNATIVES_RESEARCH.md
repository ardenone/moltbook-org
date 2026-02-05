# ArgoCD Installation Alternatives Research - ardenone-cluster

**Task**: mo-1bci - Research: Alternative ArgoCD installation methods for ardenone-cluster
**Date**: 2026-02-05
**Status**: COMPLETE

---

## Executive Summary

The devpod ServiceAccount lacks cluster-admin permissions required to install ArgoCD via manifests. This research evaluates **four alternative approaches** for installing ArgoCD in ardenone-cluster, analyzing security implications and feasibility for each.

### Current Blocker

| Check | Status | Details |
|-------|--------|---------|
| argocd namespace | NotFound | Does not exist |
| ArgoCD CRDs | Not Installed | Only Argo Rollouts CRDs exist |
| Devpod SA cluster-admin | NO | Cannot create CRDs, namespaces, ClusterRoleBindings |
| argocd-manager-role | EXISTS | Has wildcard permissions, reusable |

### Root Cause

ArgoCD installation requires **cluster-admin** privileges for:
1. Creating the `argocd` namespace (cluster-scoped resource)
2. Installing CustomResourceDefinitions (CRDs) - 15+ cluster-scoped resources
3. Creating ClusterRoles and ClusterRoleBindings for ArgoCD components
4. Deploying ArgoCD core components (API server, repo-server, application-controller, etc.)

---

## Alternative Approaches

### 1. Helm Installation (RECOMMENDED)

**Approach**: Use Helm charts to install ArgoCD from devpod with minimal elevated permissions.

#### Feasibility: MODERATE ⚠️

**Requirements**:
- Helm binary installed (NOT present in current devpod)
- RBAC to create namespace-level resources
- Pre-created `argocd` namespace by cluster-admin
- Pre-installed CRDs by cluster-admin

**Installation Process**:
```bash
# Step 1: Cluster-admin creates namespace and installs CRDs (one-time)
kubectl create namespace argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds.yaml

# Step 2: Cluster-admin grants devpod namespace-admin in argocd
kubectl create rolebinding devpod-argocd-admin \
  --clusterrole=admin \
  --serviceaccount=devpod:default \
  --namespace=argocd

# Step 3: From devpod, install ArgoCD using Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --namespace argocd
```

#### Security Analysis: MODERATE ✅

**Pros**:
- Devpod gets namespace-admin only in `argocd` namespace (principle of least privilege)
- Cluster-admin action is one-time (namespace + CRDs)
- Helm provides easier upgrades and configuration management
- Better production practice than raw manifests

**Cons**:
- Still requires cluster-admin for initial setup (namespace + CRDs)
- Helm not currently installed in devpod (would need to be added)
- More complex than direct cluster-admin installation

**Verdict**: **Viable with cluster-admin assistance**, but not fully autonomous from devpod.

---

### 2. Cluster-Admin Manual Installation (RECOMMENDED - SIMPLEST)

**Approach**: Cluster-admin installs ArgoCD directly, then devpod manages applications.

#### Feasibility: HIGH ✅

**Installation Process**:
```bash
# From cluster-admin workstation:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Or use existing prepared manifest:
kubectl apply -n argocd -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

**After Installation**:
```bash
# Devpod can then manage ArgoCD Applications
kubectl apply -f k8s/argocd-application.yml
```

#### Security Analysis: LOW RISK ✅

**Pros**:
- Simplest approach - one cluster-admin command
- Standard ArgoCD installation pattern
- Devpod can still create Applications after installation
- No RBAC complexity

**Cons**:
- Requires cluster-admin access (not available from devpod)
- Creates dependency on cluster-admin for ArgoCD lifecycle
- Devpod cannot upgrade ArgoCD without cluster-admin

**Verdict**: **RECOMMENDED** for ardenone-cluster. Simple, secure, standard pattern.

---

### 3. External GitOps (GitHub Actions) (ALTERNATIVE)

**Approach**: Use GitHub Actions with cluster credentials to apply manifests externally.

#### Feasibility: HIGH ✅

**Implementation Pattern**:
```yaml
# .github/workflows/deploy-argocd.yml
name: Deploy ArgoCD
on:
  workflow_dispatch:
  push:
    paths:
      - 'cluster-configuration/ardenone-cluster/argocd/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy ArgoCD to cluster
        uses: actions-hub/kubectl@master
        env:
          KUBE_CONFIG: ${{ secrets.KUBE_CONFIG_ARDENONE }}
        with:
          args: apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

#### Security Analysis: MODERATE-HIGH RISK ⚠️

**Pros**:
- No cluster-admin access needed from devpod
- Automated deployment pipeline
- Can be triggered from PRs with approval
- Audit trail via GitHub Actions logs

**Cons**:
- Requires storing cluster credentials in GitHub (Secrets)
- Credential exposure risk if GitHub account compromised
- External dependency on GitHub Actions availability
- More complex setup and maintenance
- Credential rotation required for security

**Verdict**: **Viable but higher security risk** than cluster-admin direct installation. Not recommended unless external automation is required.

---

### 4. Grant cluster-admin Role to devpod ServiceAccount (NOT RECOMMENDED)

**Approach**: Bind devpod ServiceAccount to cluster-admin ClusterRole.

#### Feasibility: HIGH ✅

**Implementation**:
```yaml
# cluster-configuration/ardenone-cluster/argocd/devpod-cluster-admin-rbac.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devpod-cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: devpod
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

#### Security Analysis: HIGH RISK ❌

**Pros**:
- Devpod can install ArgoCD autonomously
- Devpod can manage all cluster resources
- No dependency on cluster-admin for future operations

**Cons**:
- **SECURITY RISK**: Devpods run user code - granting cluster-admin is dangerous
- **PRIVILEGE ESCALATION**: Any compromised devpod has full cluster control
- **TENANT ISOLATION**: Breaks isolation between devpod tenants
- **OPERATIONAL RISK**: Accidental deletion of critical resources
- **AUDIBILITY**: Harder to track which devpod made changes

**Security Principles Violated**:
- **Principle of Least Privilege**: Devpod needs far less than cluster-admin
- **Defense in Depth**: Single compromised ServiceAccount compromises entire cluster
- **Tenant Isolation**: All devpods share the same ServiceAccount

**Verdict**: **NOT RECOMMENDED** - Security risk outweighs convenience.

---

## Comparison Matrix

| Approach | Feasibility | Security | Cluster-Admin Required | Devpod Autonomous | Recommendation |
|----------|------------|----------|------------------------|-------------------|----------------|
| **Helm** | MODERATE | ✅ Acceptable | Yes (one-time) | Partially | ⭐⭐⭐⭐ |
| **Cluster-Admin Direct** | HIGH | ✅ Low Risk | Yes (one-time) | No | ⭐⭐⭐⭐⭐ RECOMMENDED |
| **External GitOps** | HIGH | ⚠️ Moderate Risk | Yes (credentials) | Yes | ⭐⭐⭐ |
| **Grant cluster-admin** | HIGH | ❌ High Risk | Yes (one-time) | Yes | ❌ NOT RECOMMENDED |

---

## Recommended Approach for ardenone-cluster

### Phase 1: Initial Installation (Cluster-Admin)

```bash
# Cluster-admin executes:
kubectl create namespace argocd
kubectl apply -n argocd -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Verification:
kubectl get pods -n argocd
kubectl get crd | grep argoproj.io
```

### Phase 2: Devpod Application Management

```bash
# From devpod, after ArgoCD is installed:
kubectl apply -f k8s/argocd-application.yml
kubectl get application moltbook -n argocd
```

### Phase 3: Optional RBAC for Application Management

If devpod needs more control over ArgoCD Applications:

```yaml
# Grant devpod ability to manage Applications in argocd namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-application-manager
  namespace: argocd
rules:
- apiGroups: ["argoproj.io"]
  resources: ["applications", "appprojects"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: devpod-argocd-application-manager
  namespace: argocd
subjects:
- kind: ServiceAccount
  name: default
  namespace: devpod
roleRef:
  kind: Role
  name: argocd-application-manager
  apiGroup: rbac.authorization.k8s.io
```

---

## Security Best Practices

### ✅ DO:
- Use cluster-admin for one-time installation only
- Grant namespace-scoped permissions for ongoing operations
- Use SealedSecrets for sensitive configuration
- Audit all RBAC changes
- Review ServiceAccount permissions regularly

### ❌ DON'T:
- Grant cluster-admin to devpod ServiceAccount
- Store cluster credentials in external repositories
- Use wildcard permissions (`*`) in ClusterRoles
- Share credentials across environments
- Expose ArgoCD UI without authentication

---

## Existing Infrastructure Analysis

### Reusable Components
- ✅ `argocd-manager-role` ClusterRole exists (wildcard permissions)
- ✅ `argocd-manager-role-binding` ClusterRoleBinding exists (bound to kube-system:argocd-manager)
- ❌ Bound to wrong ServiceAccount (kube-system:argocd-manager, not devpod:default)

### Solution Pattern
Create a new ClusterRoleBinding for devpod to use the existing `argocd-manager-role`:

```bash
# Cluster-admin creates binding to existing role:
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

This is ALREADY documented in:
- `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml`
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml`

---

## Follow-Up Actions

### Immediate (Blocker Resolution)
1. **Cluster-admin applies RBAC grant**: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml`
2. **Devpod installs ArgoCD**: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
3. **Verify installation**: `kubectl get pods -n argocd`

### Future Considerations
1. **Helm migration**: Consider using Helm for easier ArgoCD upgrades
2. **External GitOps**: Evaluate GitHub Actions deployment for other clusters
3. **RBAC refinement**: Grant namespace-scoped permissions instead of cluster-admin where possible

---

## Related Documentation

- `cluster-configuration/ardenone-cluster/argocd/BLOCKER.md` - Current blocker details
- `cluster-configuration/ardenone-cluster/argocd/INSTALLATION_STATUS.md` - Installation status
- `k8s/install-argocd.sh` - Installation script (requires cluster-admin)
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Complete installation guide
- `docs/ARGOCD_ARCHITECTURE_RESEARCH.md` - Architecture analysis (mo-196j)

---

## Sources

- [Argo CD Installation Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [GitHub Issue #5389: Define minimum necessary RBAC permissions](https://github.com/argoproj/argo-cd/issues/5389)
- [DevOpsCube - How to Deploy Argo CD on Kubernetes](https://devopscube.com/setup-argo-cd-using-helm/)
- [OpsMX Blog - Argo CD Installation Comparison](https://www.opsmx.com/blog/argo-cd-installation-into-kubernetes-using-helm-or-manifest/)
- [OneUptime - Production-Ready Argo CD Guide](https://oneuptime.com/blog/post/2026-02-02-argocd-installation-configuration/view)
- [ArgoCD RBAC Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)

---

**Research Completed**: 2026-02-05
**Task**: mo-1bci
**Status**: COMPLETE
**Recommendation**: Cluster-admin direct installation (simplest, lowest risk)
