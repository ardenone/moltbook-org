# ArgoCD Installation Blocker - mo-y5o

**Bead ID**: mo-1fgm (task), mo-172o (P0 blocker)
**Status**: BLOCKED - Requires Cluster Admin Action
**Priority**: P0 (Critical)
**Date**: 2026-02-05
**Updated**: 2026-02-05 05:32 UTC - Created consolidated blocker bead mo-172o

## Executive Summary

ArgoCD is **not installed** in ardenone-cluster (namespace `argocd` does not exist). The Moltbook ArgoCD Application at `k8s/argocd-application.yml` cannot sync without ArgoCD installed.

## Current State

| Resource | Status | Command Verified |
|----------|--------|------------------|
| Namespace `argocd` | Does NOT exist | `kubectl get namespace argocd` |
| CRD `applications.argoproj.io` | Does NOT exist | `kubectl get crd applications.argoproj.io` |
| Namespace `moltbook` | Does NOT exist | `kubectl get namespace moltbook` |
| Devpod SA cluster-admin | Denied | `kubectl auth can-i create crd` |

## Root Cause

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the cluster-admin privileges required to:

1. **Create CustomResourceDefinitions (CRDs)** - cluster-scoped resource
2. **Create ClusterRole/ClusterRoleBinding** - cluster-scoped resources
3. **Create argocd namespace** - cluster-scoped resource

## Resolution Path

### Single Command (Cluster Admin Required)

A cluster-admin must run this **one-time** command:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

This creates:
1. `argocd-installer` ClusterRole with necessary permissions
2. `devpod-argocd-installer` ClusterRoleBinding (binds to devpod:default ServiceAccount)
3. `argocd` namespace
4. `moltbook` namespace

### After Cluster Admin Applies RBAC

From the devpod, run:

```bash
# Option 1: Install ArgoCD from local manifest (faster, no network dependency)
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Option 2: Install ArgoCD from upstream (latest version)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Deploy Moltbook via ArgoCD
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

### Verification

```bash
# Verify ArgoCD is running
kubectl get pods -n argocd

# Verify Moltbook Application
kubectl get application moltbook -n argocd
```

## Alternative: Direct Installation (No RBAC)

If cluster admin prefers to install ArgoCD directly:

```bash
kubectl create namespace argocd
kubectl create namespace moltbook
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Related Blocker Beads

- mo-3oja - CRITICAL: ArgoCD installation blocked - requires cluster-admin
- mo-12bv - BLOCKER: Cluster-admin must install ArgoCD in ardenone-cluster
- mo-3200 - Fix: Apply argocd-installer RBAC and install ArgoCD
- mo-1te - Moltbook RBAC Blocker Status (namespace creation)

## Documentation

- `ARGOCD_INSTALLATION_GUIDE.md` - Comprehensive installation guide (created 2026-02-05)
- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - Alternative RBAC manifest
- `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` - Local ArgoCD installation manifest (1.8MB, 59 resources)
- `k8s/argocd-application.yml` - ArgoCD Application for Moltbook
- `MOLTBOOK_RBAC_BLOCKER_STATUS.md` - Related namespace blocker
