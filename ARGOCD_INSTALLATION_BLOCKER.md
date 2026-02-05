# ArgoCD Installation Blocker - ardenone-cluster

**Bead ID**: mo-1fgm → mo-28ns (blocker created)
**Date**: 2026-02-05
**Status**: BLOCKED - Requires Cluster Admin Action
**Priority**: P0 (Critical)

## Executive Summary

ArgoCD is **NOT installed** in ardenone-cluster. Installing ArgoCD requires cluster-admin privileges which the devpod ServiceAccount does not have. This blocks automated GitOps deployment of Moltbook and future applications.

## Current State Analysis

### What Exists
| Resource | Status | Details |
|----------|--------|---------|
| Namespace `argocd` | Does NOT exist | Needs to be created |
| ArgoCD CRDs | NOT installed | `applications.argoproj.io` CRD missing |
| Namespace `moltbook` | Does NOT exist | Needs to be created |
| `argocd-proxy` | EXISTS in devpod ns | Proxies to argocd-manager.ardenone.com |
| External ArgoCD | EXISTS | argocd-manager.ardenone.com (HTTP 200) |

### External ArgoCD Discovery
The cluster has an `argocd-proxy` deployment in the `devpod` namespace that points to `argocd-manager.ardenone.com`. This is a **centralized ArgoCD instance** that manages this cluster externally. However, for **local GitOps deployments** (like Moltbook), ArgoCD needs to be installed **within** ardenone-cluster.

### Current RBAC Permissions
The devpod ServiceAccount (`system:serviceaccount:devpod:default`) has:
- `get/list/watch` on many resources (including existing Argo Rollouts CRDs)
- **NO** `create` on `customresourcedefinitions.apiextensions.k8s.io`
- **NO** `create` on `namespaces`
- **NO** `create` on `clusterroles` or `clusterrolebindings`

## Resolution Path

### Step 1: Cluster Admin Action (REQUIRED)

A cluster-admin must apply the RBAC manifest:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

This creates:
1. `argocd-installer` ClusterRole with ArgoCD installation permissions
2. `devpod-argocd-installer` ClusterRoleBinding (binds to devpod:default)
3. `argocd` namespace
4. `moltbook` namespace

### Step 2: Install ArgoCD (from devpod, after RBAC is applied)

```bash
# Install ArgoCD from official manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Verify installation
kubectl get pods -n argocd
```

### Step 3: Deploy Moltbook via ArgoCD

```bash
# Apply the Moltbook Application manifest
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# Check sync status
kubectl get application moltbook -n argocd
```

## Alternative: Direct kubectl Deployment

If ArgoCD is not desired, Moltbook can be deployed directly:

```bash
# After RBAC is applied
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

## Verification Commands

After installation, verify with:

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD CRDs
kubectl get crd | grep argoproj

# Check Moltbook Application
kubectl get application moltbook -n argocd

# Check ArgoCD API
kubectl port-forward svc/argocd-server -n argocd 8080:443
curl -k https://localhost:8080/healthz
```

## Related Beads

- **mo-28ns** (P0) - BLOCKER: ArgoCD installation requires cluster-admin RBAC [NEW]
- **mo-1fgm** (P0) - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments [CURRENT]
- **mo-y5o** (P0) - Previous ArgoCD blocker attempt

## Files Reference

| File | Purpose |
|------|---------|
| `k8s/ARGOCD_INSTALL_REQUEST.yml` | RBAC manifest for cluster-admin |
| `k8s/install-argocd.sh` | Automated installation script |
| `k8s/verify-argocd-ready.sh` | Pre-installation verification |
| `k8s/argocd-application.yml` | Moltbook ArgoCD Application |
