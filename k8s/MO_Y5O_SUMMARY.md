# Task mo-y5o Summary: ArgoCD Installation Analysis

**Task ID:** mo-y5o
**Title:** CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date:** 2026-02-04
**Status:** BLOCKED - Cluster Admin Action Required

## Executive Summary

The task to install ArgoCD locally in ardenone-cluster is **blocked by RBAC permissions**. The devpod ServiceAccount lacks cluster-admin privileges required to install ArgoCD (create CRDs, cluster-scoped resources).

**CRITICAL FINDING:** The architecture analysis reveals that an **external ArgoCD server** already exists at `argocd-manager.ardenone.com`. Local ArgoCD installation is **NOT the recommended approach**.

## Current State

| Component | Status | Details |
|-----------|--------|---------|
| Local ArgoCD | Not Installed | Namespace 'argocd' does not exist |
| External ArgoCD | Running | argocd-manager.ardenone.com (HTTP 200) |
| argocd-proxy | Running | devpod namespace (10.43.174.252:8080) |
| RBAC (argocd-installer) | Not Applied | Requires cluster-admin |
| moltbook namespace | Not Created | Requires cluster-admin |

## Blockers Identified

### 1. RBAC Blocker (Priority 0)
The devpod ServiceAccount cannot create cluster-scoped resources:
```
Error: clusterroles.rbac.authorization.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "clusterroles"
```

**Required Action:** Cluster admin must apply RBAC configuration
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

### 2. Namespace Blocker (Priority 0)
The `moltbook` namespace does not exist and cannot be created from devpod.

**Required Action:** Cluster admin must apply namespace setup
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

## Recommended Approach: External ArgoCD

Based on `k8s/ARGOCD_ARCHITECTURE_ANALYSIS.md`:

1. **External ArgoCD exists** at argocd-manager.ardenone.com
2. **argocd-proxy** provides read-only access from devpod
3. **Local installation adds unnecessary operational overhead**

### Deployment Path via External ArgoCD

1. Cluster admin creates moltbook namespace
2. Grant devpod SA permissions to manage moltbook namespace
3. Create Application on external ArgoCD targeting ardenone-cluster
4. ArgoCD syncs manifests from moltbook-org repository

## Beads Created

| Bead ID | Priority | Title |
|---------|----------|-------|
| mo-3200 | P0 | Fix: Apply argocd-installer RBAC and install ArgoCD in ardenone-cluster |
| mo-3r0e | P0 | Architecture: Use external ArgoCD for Moltbook deployment - NOT local installation |
| mo-16rc | P0 | CRITICAL: Grant cluster-admin RBAC to devpod for Moltbook deployment |

## Alternative: Direct kubectl Deployment

If ArgoCD installation is not feasible, Moltbook can be deployed directly:

```bash
# Requires cluster-admin for namespace creation
kubectl create namespace moltbook

# Apply RBAC for devpod SA
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml

# Deploy all resources
kubectl apply -k k8s/
```

**Note:** This approach violates GitOps principles and requires manual updates for future changes.

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz

# Check for local ArgoCD (should return nothing)
kubectl get namespace argocd

# Check moltbook namespace (should return "not found")
kubectl get namespace moltbook

# Check devpod SA permissions
kubectl auth can-i create customresourcedefinitions
kubectl auth whoami
```

## References

- `k8s/ARGOCD_ARCHITECTURE_ANALYSIS.md` - Architecture analysis
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Installation guide
- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC configuration
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Namespace setup
- `k8s/argocd-application.yml` - Application manifest

## Next Steps

1. **Cluster admin applies RBAC:** `kubectl apply -f k8s/ARGOCD_INSTALL_REQUEST.yml`
2. **Cluster admin creates namespace:** `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
3. **Choose deployment approach:**
   - External ArgoCD (recommended) - link to bead mo-3r0e
   - Local ArgoCD installation - requires RBAC from mo-3200
   - Direct kubectl - bypass ArgoCD entirely
