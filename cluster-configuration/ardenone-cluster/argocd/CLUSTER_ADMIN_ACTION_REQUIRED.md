# CRITICAL: Cluster Admin Action Required for ArgoCD Installation

## Status: BLOCKED - Requires Cluster Admin Intervention

### Problem
ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount lacks the cluster-scoped permissions required to install ArgoCD.

### Current State Analysis (2026-02-05)

**Ardenone-Cluster:**
- **ArgoCD Namespace**: Does NOT exist
- **ArgoCD CRDs**: NOT installed
- **ArgoCD Installation**: NOT performed

**RBAC Situation:**
- **Existing ClusterRole**: `argocd-manager-role` exists with full cluster-admin permissions (wildcard on all resources)
- **Current Binding**: Bound to `kube-system:argocd-manager` ServiceAccount
- **DevPod SA**: Has only read-only access via `mcp-k8s-observer-cluster-resources` ClusterRole
- **Missing**: ClusterRoleBinding from devpod SA to `argocd-manager-role`

### Required Action (Cluster Admin Only)

**Apply this single manifest to grant devpod the required permissions:**

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
```

This creates a ClusterRoleBinding that:
- Binds `argocd-manager-role` (full cluster-admin equivalent) to `devpod:default` ServiceAccount
- Enables the devpod to install ArgoCD

### After Cluster Admin Action

Once the ClusterRoleBinding is applied, from the devpod run:

```bash
# Verify permissions
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default

# Install ArgoCD
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Verify installation
kubectl get pods -n argocd
kubectl get deployment argocd-server -n argocd
```

### What Happens Next

After ArgoCD is installed:
1. The ArgoCD Application manifest at `k8s/argocd-application.yml` will sync automatically
2. Moltbook and all future applications can be deployed via GitOps
3. No more manual `kubectl apply` required

### Verification Commands

```bash
# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-argocd-manager

# Verify devpod can create namespaces
kubectl auth can-i create namespace --as=system:serviceaccount:devpod:default

# Check if ArgoCD is running
kubectl get pods -n argocd
```

---

**Prepared by:** Claude Code (task mo-3ki8, updated for mo-y3id)
**Date:** 2026-02-05 (Updated - Blocker Still Active)
**Priority:** P0 - CRITICAL BLOCKER
**Related Beads**: mo-y3id (P0), mo-2e6h (P1)
**Supersedes**: mo-3ki8 (incorrectly closed)
**Last Verified:** 2026-02-05 - ClusterRoleBinding `devpod-argocd-manager` STILL NOT FOUND
