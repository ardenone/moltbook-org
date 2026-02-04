# Moltbook Deployment Status - mo-272

**Bead ID:** mo-272
**Title:** Deploy: Apply Moltbook manifests to ardenone-cluster
**Date:** 2026-02-04
**Status:** BLOCKED - Requires cluster-admin intervention

---

## Executive Summary

Task mo-272 requires applying Moltbook manifests to ardenone-cluster. The manifests are **already committed** to the ardenone-cluster repository at `cluster-configuration/ardenone-cluster/moltbook/`. However, deployment is **BLOCKED** due to missing infrastructure prerequisites:

1. **moltbook namespace does not exist** - Cannot be created without cluster-admin permissions
2. **RBAC not granted** - The `devpod-namespace-creator` ClusterRoleBinding is not applied
3. **ArgoCD not installed** - GitOps sync is not available

---

## Current State Analysis

### Repository Status: ardenone-cluster

**Location:** `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`

All manifests are committed and pushed to GitHub (commit 6331715a):

| Component | Status |
|-----------|--------|
| namespace.yml | Committed (includes RBAC) |
| kustomization.yml | Committed |
| argocd-application.yml | Committed |
| api/ | Committed (deployment, service, ingressroute, configmap) |
| database/ | Committed (CNPG cluster, schema init, service) |
| frontend/ | Committed (deployment, service, ingressroute, configmap) |
| redis/ | Committed (deployment, service, configmap) |
| secrets/ | Committed (SealedSecrets for API and DB) |

**Total:** 24+ manifest files across all components

### Cluster State: ardenone-cluster

| Resource | Status | Details |
|----------|--------|---------|
| moltbook namespace | Not Found | Cannot be created by devpod SA |
| namespace-creator ClusterRole | Not Found | Requires cluster-admin to apply |
| devpod-namespace-creator ClusterRoleBinding | Not Found | Requires cluster-admin to apply |
| ArgoCD | Not Installed | No argocd namespace exists |

---

## Blockers Identified

### Blocker #1: Namespace Creation Permission (CRITICAL - P0)

**Error:**
```
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```

**Required Action (Cluster Admin Only):**
```bash
# Apply the ClusterRole and ClusterRoleBinding
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

### Blocker #2: ArgoCD Not Installed (CRITICAL - P0)

The task description states "ArgoCD will sync" but ArgoCD is not installed in ardenone-cluster.

**Impact:**
- Cannot use GitOps deployment pattern
- Must deploy manually via kubectl after namespace is created

**Workaround:**
- Use direct `kubectl apply -k` deployment after RBAC is granted

---

## Resolution Path

### Option A: Cluster Admin Creates RBAC (Recommended)

1. **Cluster admin applies RBAC manifest:**
   ```bash
   kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
   ```

2. **Verify RBAC is applied:**
   ```bash
   kubectl get clusterrole namespace-creator
   kubectl get clusterrolebinding devpod-namespace-creator
   ```

3. **Create namespace and deploy:**
   ```bash
   kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace.yml
   kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
   ```

### Option B: Cluster Admin Creates Namespace Directly

1. **Cluster admin creates namespace:**
   ```bash
   kubectl create namespace moltbook
   ```

2. **Deploy all resources:**
   ```bash
   kubectl apply -k /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
   ```

---

## Verification Commands (After Blockers Are Resolved)

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Verify all resources deployed
kubectl get all -n moltbook
kubectl get clusters -n moltbook
kubectl get ingressroutes -n moltbook

# Check pod health
kubectl get pods -n moltbook

# Test endpoints
curl https://api-moltbook.ardenone.com/health
curl https://moltbook.ardenone.com
```

---

## Related Beads (Blockers)

Existing beads tracking these blockers:
- mo-2qk4 [P0] - BLOCKED: Cluster-admin must create moltbook namespace for deployment
- mo-3aw [P0] - Fix: Create moltbook namespace in ardenone-cluster
- mo-32d [P0] - Fix: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook

**New bead created:**
- mo-3ieu [P0] - Admin: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook deployment

---

## Task Completion Assessment

**Task mo-272 Status:** BLOCKED

**What Was Completed:**
- Verified all manifests exist in ardenone-cluster repository
- Confirmed manifests are committed and pushed to GitHub (commit 6331715a)
- Analyzed deployment blockers
- Documented resolution path
- Created blocker bead mo-3ieu for cluster-admin intervention

**What Cannot Be Completed (Requires Cluster Admin):**
- Cannot create moltbook namespace (insufficient permissions)
- Cannot apply ClusterRole/ClusterRoleBinding (insufficient permissions)
- Cannot deploy manifests without namespace

---

## Conclusion

The Moltbook manifests are **ready for deployment** in the ardenone-cluster repository. However, actual deployment is **blocked** by missing RBAC permissions for namespace creation.

Once a cluster administrator applies the `devpod-namespace-creator-rbac.yml` manifest or creates the namespace directly, the deployment can proceed using the existing manifests.

**Estimated Time to Deploy After Unblock:** 5-10 minutes

---

**Status:** BLOCKED - Awaiting cluster-admin intervention
**Date:** 2026-02-04
**Bead:** mo-272
