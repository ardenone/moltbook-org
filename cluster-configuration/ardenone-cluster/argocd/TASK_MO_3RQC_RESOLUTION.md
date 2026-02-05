# Task mo-3rqc Resolution: ArgoCD Installation for Moltbook

**Task ID**: mo-3rqc
**Title**: CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Status**: BLOCKED - Requires Cluster-Admin Action
**Date**: 2026-02-05

---

## Executive Summary

The task to install ArgoCD locally in ardenone-cluster is **blocked by RBAC restrictions**. The devpod ServiceAccount lacks the cluster-admin permissions required to install ArgoCD (creating CRDs, ClusterRoles, namespaces).

**However**, architectural analysis reveals that an **external ArgoCD server at `argocd-manager.ardenone.com` is already available and healthy**. This external ArgoCD is the intended deployment mechanism for Moltbook.

---

## Current State

| Component | Status | Details |
|-----------|--------|---------|
| External ArgoCD | ✅ **ONLINE** | `argocd-manager.ardenone.com` health check returns "ok" |
| argocd-proxy | ✅ **RUNNING** | Read-only proxy in devpod namespace |
| Local ArgoCD | ❌ **NOT INSTALLED** | No argocd namespace, no ArgoCD CRDs |
| Argo Rollouts | ✅ **INSTALLED** | CRDs present (different product from ArgoCD) |
| devpod RBAC | ❌ **INSUFFICIENT** | Cannot create namespaces, CRDs, or ClusterRoles |

---

## Two Resolution Paths

### Path A: Install Local ArgoCD (As Task Specifies)

**Requires**: Cluster-admin to apply ARGOCD_SETUP_REQUEST.yml

```bash
# Step 1: Cluster admin applies RBAC grant
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml

# Step 2: From devpod, install ArgoCD
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

**Pros**: Self-contained ArgoCD installation
**Cons**: Requires cluster-admin, duplicates existing external ArgoCD

### Path B: Use External ArgoCD (RECOMMENDED)

**Requires**: Cluster-admin to apply NAMESPACE_SETUP_REQUEST.yml

```bash
# Step 1: Cluster admin creates namespace
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml

# Step 2: Register Moltbook with external ArgoCD at argocd-manager.ardenone.com
# (via UI or API using the ArgoCD Application manifest)
```

**Pros**: Uses existing infrastructure, follows intended architecture
**Cons**: Requires cluster-admin for namespace creation

---

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz
# Expected: "ok"

# Check local ArgoCD (should not exist)
kubectl get namespace argocd
# Expected: Error from server (NotFound)

# Check argocd-proxy status
kubectl get deployment argocd-proxy -n devpod
# Expected: Deployment with 1 ready replica

# Check moltbook namespace (after cluster-admin action)
kubectl get namespace moltbook
# Expected: NotFound (until cluster-admin creates it)
```

---

## Files Prepared

1. **ARGOCD_SETUP_REQUEST.yml** - RBAC manifest for local ArgoCD installation
2. **argocd-install.yml** - Official ArgoCD v2.13+ installation manifest
3. **NAMESPACE_SETUP_REQUEST.yml** - RBAC manifest for external ArgoCD path
4. **k8s/argocd-application.yml** - ArgoCD Application manifest for Moltbook

---

## Related Documentation

- `ARGOCD_ARCHITECTURE_ANALYSIS.md` - Details on external vs local ArgoCD
- `ARGOCD_PATH_FORWARD.md` - Recommended deployment path
- `BLOCKER.md` - Detailed blocker analysis

---

## Next Steps

**For Cluster-Admin:**

**Option A (Local ArgoCD)**:
1. Apply `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml`
2. Devpod will install ArgoCD using `argocd-install.yml`

**Option B (External ArgoCD - Recommended)**:
1. Apply `cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml`
2. Devpod can then deploy Moltbook resources or register with external ArgoCD

---

## Related Beads

- mo-4n69 (P0): ADMIN: Cluster Admin Action - Apply NAMESPACE_SETUP_REQUEST.yml
- mo-2fwe (P0): BLOCKER: Cluster-admin must apply ArgoCD RBAC before installation
- mo-3r0e (P0): Architecture: Use external ArgoCD for Moltbook deployment

---

## Resolution Status (2026-02-05 01:31 UTC)

**Task Status**: BLOCKED - Awaiting cluster-admin action

**Actions Taken**:
1. Verified current RBAC status - devpod SA lacks cluster-admin permissions
2. Confirmed argocd-installer ClusterRole does NOT exist
3. Confirmed devpod-argocd-installer ClusterRoleBinding does NOT exist
4. Confirmed ArgoCD CRDs (applications.argoproj.io, appprojects.argoproj.io) are NOT installed
5. Verified external ArgoCD at argocd-manager.ardenone.com is healthy (returns "ok")
6. Confirmed moltbook namespace does NOT exist
7. Created bead **mo-1qcw** (P0) to track cluster-admin action required for this task iteration

**Existing Related Beads** (all OPEN):
- mo-2zir: "ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml" (Priority 0 - Critical)
- mo-5e25: "CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster" (Priority 0)
- mo-3k53: "BLOCKER: Cluster-admin must apply ArgoCD RBAC before installation" (Priority 0)
- mo-4n69: "ADMIN: Cluster Admin Action - Apply NAMESPACE_SETUP_REQUEST.yml" (Priority 0)

**Bead Created**:
- mo-1qcw: "ADMIN: Cluster-admin action needed - Apply ARGOCD_SETUP_REQUEST.yml for mo-3rqc" (Priority 0 - Critical)

## Cluster Admin Instructions

To resolve this blocker, a cluster-admin must:

```bash
# Step 1: Apply RBAC grant for ArgoCD installation
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml

# Step 2: Verify RBAC was applied (from devpod)
kubectl get clusterrole argocd-installer
kubectl get clusterrolebinding devpod-argocd-installer
```

Once RBAC is applied, the devpod can complete the installation:

```bash
# Step 3: Install ArgoCD (from devpod, after RBAC)
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Step 4: Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Step 5: Apply Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```
