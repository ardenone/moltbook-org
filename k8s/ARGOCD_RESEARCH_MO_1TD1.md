# ArgoCD Installation Research - mo-1td1

**Bead**: mo-1td1
**Title**: Research: Install ArgoCD in ardenone-cluster
**Date**: 2026-02-05
**Status**: RESEARCH COMPLETE - Local ArgoCD Installation NOT Recommended

---

## Executive Summary

**Finding**: Installing ArgoCD locally in ardenone-cluster is **NOT the recommended approach**. The organization uses an **external ArgoCD server** at `argocd-manager.ardenone.com` for GitOps deployments across multiple clusters including ardenone-cluster.

**Recommendation**: Use external ArgoCD or direct kubectl deployment (PATH 2). Local ArgoCD installation would be redundant and create operational overhead.

---

## Research Findings

### 1. External ArgoCD Already Exists

| Component | Status | Details |
|-----------|--------|---------|
| External ArgoCD Server | ✅ Running | argocd-manager.ardenone.com |
| HTTP Health Check | ✅ HTTP 200 | Returns HTML response |
| argocd-proxy Deployment | ✅ Running | devpod namespace, pod: argocd-proxy-8686d5cb95-d5tvk |
| argocd-proxy ConfigMap | ✅ Present | ARGOCD_SERVER: argocd-manager.ardenone.com |

### 2. Local ArgoCD Status

| Component | Status | Details |
|-----------|--------|---------|
| argocd namespace | ❌ Does NOT exist | Not installed locally |
| ArgoCD CRDs | ⚠️ Partial | 4 argoproj.io CRDs (Argo Rollouts, NOT ArgoCD) |
| ArgoCD pods | ❌ None running | Local installation not performed |

### 3. Existing Architecture

The argocd-proxy in devpod namespace provides a **read-only interface** to external ArgoCD:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-proxy
  namespace: devpod
spec:
  template:
    spec:
      containers:
      - name: argocd-proxy
        image: ronaldraygun/argocd-proxy:1.0.2
        env:
        - name: ARGOCD_SERVER
          value: argocd-manager.ardenone.com
        - name: ARGOCD_AUTH_TOKEN
          valueFrom:
            secretKeyRef:
              name: argocd-readonly
              key: ARGOCD_AUTH_TOKEN
```

**Note**: The argocd-readonly token is **expired** (bead mo-dbl7 tracks this).

---

## Why Local ArgoCD Installation is NOT Recommended

### 1. Redundancy

External ArgoCD at `argocd-manager.ardenone.com` already serves as the GitOps controller for multiple clusters. Installing a local instance would create:
- Duplicate GitOps infrastructure
- Additional operational overhead
- Configuration complexity

### 2. Architecture Pattern

Per `ARGOCD_ARCHITECTURE_ANALYSIS.md`:
```
argocd-manager.ardenone.com (External ArgoCD)
    ↓ (manages multiple clusters)
    ├── ardenone-cluster
    │   └── [moltbook namespace - to be created]
    └── [other clusters]
```

This is the **intended architecture** for the organization.

### 3. Deployment Path Decision (mo-1ts4)

**PATH 2 (kubectl manual) was selected** over ArgoCD GitOps because:
- External ArgoCD read-only token is expired (mo-dbl7)
- Local ArgoCD installation is redundant
- kubectl deployment unblocks Moltbook immediately after namespace RBAC

---

## Current Deployment Options

### Option 1: External ArgoCD GitOps (BLOCKED)

**Prerequisites**:
1. Cluster admin creates namespace: `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Resolve expired argocd-readonly token (mo-dbl7)

**Then**:
1. Create Application on external ArgoCD
2. ArgoCD syncs manifests automatically

### Option 2: Direct kubectl apply (SELECTED - mo-1ts4)

**Prerequisites**:
1. Cluster admin creates namespace: `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`

**Then**:
1. Deploy from devpod: `kubectl apply -k k8s/`
2. Manual maintenance (no auto-sync)

**Note**: Can migrate to external ArgoCD GitOps later when credentials are resolved.

### Option 3: Install Local ArgoCD (NOT RECOMMENDED)

**Prerequisites**:
1. Cluster admin applies RBAC: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml`

**Then**:
1. Install ArgoCD: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
2. Configure local ArgoCD
3. Create Application manifest

**Why NOT recommended**:
- External ArgoCD already exists
- Additional cluster-admin overhead
- Not the intended architecture
- Creates operational redundancy

---

## Current Blockers

### 1. Namespace Creation (Priority 0)

The `moltbook` namespace does not exist and cannot be created from devpod due to RBAC restrictions.

**Resolution**: Apply `k8s/NAMESPACE_SETUP_REQUEST.yml` with cluster-admin access.

### 2. External ArgoCD Access (Priority 1)

The `argocd-readonly` secret token is expired (bead mo-dbl7).

**Resolution**: Request fresh ArgoCD read-only token or admin credentials.

---

## Cluster-Admin Action Required

For any deployment path, cluster-admin must apply:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
- `namespace-creator` ClusterRole (namespace permissions)
- `devpod-namespace-creator` ClusterRoleBinding
- `moltbook` namespace

**After RBAC is applied**:
- Devpod can deploy with `kubectl apply -k k8s/` (PATH 2)
- Or wait for external ArgoCD credentials to use GitOps (PATH 1)

---

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk -I https://argocd-manager.ardenone.com

# Check for local ArgoCD (should return nothing)
kubectl get namespace argocd
kubectl get pods -n argocd

# Check argocd-proxy
kubectl get deployment argocd-proxy -n devpod

# Check moltbook namespace status
kubectl get namespace moltbook
```

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| **mo-1td1** | **Research: Install ArgoCD in ardenone-cluster** | **P1** | **This task** |
| **mo-1ts4** | **Deployment path decision - PATH 2 selected** | P1 | CLOSED |
| mo-dbl7 | Fix: Expired argocd-readonly token | P0 | OPEN |
| mo-3ff2 | CLUSTER-ADMIN: Apply ARGOCD_SETUP_REQUEST.yml RBAC manifest | P0 | OPEN |
| mo-2nwc | BLOCKER: Cluster-admin action required for ArgoCD setup | P0 | OPEN |

---

## Related Documentation

- `k8s/DEPLOYMENT_PATH_DECISION.md` - PATH 2 selection rationale
- `k8s/ARGOCD_ARCHITECTURE_ANALYSIS.md` - External vs local ArgoCD analysis
- `k8s/CLUSTER_ADMIN_README.md` - Namespace setup instructions
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - RBAC + namespace manifest
- `cluster-configuration/ardenone-cluster/argocd/` - Local ArgoCD manifests (NOT USED)

---

## Conclusion

**Research Finding**: Local ArgoCD installation in ardenone-cluster is **NOT recommended**.

**Reasoning**:
1. External ArgoCD at `argocd-manager.ardenone.com` already serves this cluster
2. PATH 2 (kubectl manual) was selected as deployment approach (mo-1ts4)
3. Local installation would create redundancy and operational overhead

**Recommended Path Forward**:
1. Cluster-admin applies `k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Devpod deploys Moltbook with `kubectl apply -k k8s/` (PATH 2)
3. Later: Migrate to external ArgoCD GitOps when mo-dbl7 (credentials) is resolved

**No local ArgoCD installation is required** for Moltbook deployment.

---

**Research Completed**: 2026-02-05
**Bead Status**: Ready for commit
**Commit Message**: "feat(mo-1td1): Research: Install ArgoCD in ardenone-cluster"
