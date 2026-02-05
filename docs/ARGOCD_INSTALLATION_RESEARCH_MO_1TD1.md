# mo-1td1: Research - Install ArgoCD in ardenone-cluster

**Task**: mo-1td1 - Research: Install ArgoCD in ardenone-cluster
**Date**: 2026-02-05
**Status**: **RESEARCH COMPLETE**
**Worker**: claude-glm-charlie
**Priority**: P1 (High)

---

## Executive Summary

### Research Question: How do we install ArgoCD in ardenone-cluster?

**Answer: Two paths exist, both have blockers**

| Path | Description | Blocker | Effort |
|------|-------------|---------|--------|
| **PATH 1: External ArgoCD** | Use existing `argocd-manager.ardenone.com` | Expired credentials (`mo-dbl7`) | Low (after credential fix) |
| **PATH 2: Local Installation** | Install ArgoCD in-cluster via manifests | Requires cluster-admin (`mo-218h`) | Medium (one-time setup) |

**Previous Decision (mo-1ts4)**: PATH 2 (kubectl manual) was selected due to credential expiration.

---

## Current State (Verified 2026-02-05)

### Local ArgoCD Status

```
argocd namespace:         NOT FOUND
ArgoCD CRDs:              NOT INSTALLED
Application CRD:          NOT FOUND
argocd-server deployment: NOT FOUND
```

**Only Argo Rollouts CRDs exist** (not ArgoCD):
- `analysisruns.argoproj.io`
- `analysistemplates.argoproj.io`
- `experiments.argoproj.io`
- `rollouts.argoproj.io`

### External ArgoCD Status

```
argocd-manager.ardenone.com:  ONLINE (verified)
DNS:                          10.20.23.100
Health check:                 https://argocd-manager.ardenone.com/healthz → "ok"
argocd-proxy:                 Running (pod: argocd-proxy-8686d5cb95-d5tvk)
Proxy health:                 http://10.43.174.252:8080/healthz → "OK"
```

---

## Installation Methods

### Method 1: External ArgoCD (Hub-and-Spoke)

**Architecture:**
```
argocd-manager.ardenone.com (Hub)
        |
        v
ardenone-cluster (Spoke)
        |
        +-- Application manifests deployed from external GitOps controller
```

**Requirements:**
- ✅ External ArgoCD is online and healthy
- ❌ Valid admin credentials for `argocd-manager.ardenone.com`
- ❌ Cluster registration with external ArgoCD

**Blocker:**
- `mo-dbl7` - Expired `argocd-readonly` token in `devpod` namespace
- Need admin credentials to create Applications

**Advantages:**
- Follows existing hub-and-spoke pattern
- No additional resource consumption in ardenone-cluster
- Built-in multi-cluster management

---

### Method 2: Local ArgoCD Installation

**Architecture:**
```
ardenone-cluster
        |
        +-- argocd namespace (new)
                |
                +-- argocd-server (API + UI)
                +-- argocd-repo-server (Git sync)
                +-- argocd-application-controller (Sync controller)
                +-- argocd-dex-server (Auth)
                +-- argocd-redis (Cache)
```

**Requirements:**
- ❌ Cluster-admin RBAC (to create CRDs, ClusterRoleBindings, namespace)
- ✅ Installation manifest exists: `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
- ✅ Official ArgoCD v2.9+ manifest (1.8MB)

**Blocker:**
- `mo-218h` - Cluster-admin must apply `ARGOCD_SETUP_REQUEST.yml` first
- Devpod ServiceAccount (`devpod:default`) cannot create cluster-scoped resources

**Installation Steps (requires cluster-admin):**

```bash
# Step 1: Cluster-admin applies RBAC grant
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml

# Step 2: From devpod, apply ArgoCD manifest
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Step 3: Verify installation
kubectl get pods -n argocd
kubectl get crd | grep argocd
```

**Resource Requirements:**
- Memory: ~2GB minimum
- CPU: ~1 core minimum

**Advantages:**
- Full local control of ArgoCD
- No dependency on external services
- Can be managed entirely from devpod after initial setup

---

## Cluster-Admin Action Required

### What Needs to Be Applied

**File:** `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml`

**This creates:**
1. `devpod-argocd-manager` ClusterRoleBinding (grants devpod SA access to `argocd-manager-role`)
2. `argocd` namespace

**Contents:**
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

### Why This is Required

| Resource | Scope | Devpod SA Permission |
|----------|-------|---------------------|
| ClusterRoleBinding | Cluster | ❌ Cannot create |
| Namespace | Cluster | ❌ Cannot create |
| CustomResourceDefinition | Cluster | ❌ Cannot create |

The `argocd-manager-role` ClusterRole already exists with wildcard permissions, but the devpod ServiceAccount is not bound to it via a ClusterRoleBinding.

---

## Related Beads

| Bead | Priority | Description |
|------|----------|-------------|
| mo-1fgm | P0 | CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments |
| mo-218h | P0 | ADMIN: Cluster Admin Action - Apply ArgoCD RBAC for mo-1fgm |
| mo-196j | P1 | Research: ArgoCD architecture - external vs local |
| mo-dbl7 | P1 | Fix expired argocd-readonly token |
| mo-1ts4 | P1 | Deployment path decision (selected PATH 2 - kubectl manual) |
| mo-2zir | - | ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml |

---

## Recommendation

Given the previous decision in `mo-1ts4` to proceed with PATH 2 (kubectl manual), **the recommended path forward is:**

1. **Create blocker bead** for cluster-admin action to apply `ARGOCD_SETUP_REQUEST.yml`
2. **Wait for cluster-admin** to create ClusterRoleBinding and namespace
3. **Apply ArgoCD manifest** from devpod once RBAC is in place
4. **Deploy Moltbook Application** via `k8s/argocd-application.yml`

**Alternative path** (if cluster-admin is unavailable):
- Resolve `mo-dbl7` (expired credentials)
- Use external ArgoCD at `argocd-manager.ardenone.com`

---

## Verification Commands

```bash
# Check if namespace exists (after cluster-admin action)
kubectl get namespace argocd

# Check if ClusterRoleBinding exists (after cluster-admin action)
kubectl get clusterrolebinding devpod-argocd-manager

# Check if ArgoCD is installed (after manifest apply)
kubectl get pods -n argocd

# Check ArgoCD CRDs
kubectl get crd | grep 'applications\.argoproj\.io'

# Check argocd-proxy status
kubectl get pods -n devpod -l app=argocd-proxy

# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz
```

---

## Documentation References

- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_INSTALL_REQUIRED.md` - Detailed installation guide
- `docs/ARGOCD_ARCHITECTURE_RESEARCH_FEB_2026.md` - External vs local analysis
- `docs/ARGOCD_CLUSTER_ADMIN_ACTION_REQUIRED_MO_2ZIR.md` - RBAC requirements
- `k8s/argocd-application.yml` - Moltbook Application manifest (requires ArgoCD installed)

---

**Research Completed**: 2026-02-05
**Commit Message**: feat(mo-1td1): Research: Install ArgoCD in ardenone-cluster
