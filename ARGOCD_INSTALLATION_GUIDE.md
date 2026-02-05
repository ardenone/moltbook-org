# ArgoCD Installation Guide for ardenone-cluster

**Status**: BLOCKER - Requires Cluster Admin Action
**Task**: mo-1fgm
**Date**: 2026-02-05

## Problem Summary

ArgoCD is NOT installed in ardenone-cluster. Without ArgoCD, we cannot use GitOps deployment for Moltbook and future applications.

## Current State

| Resource | Status |
|----------|--------|
| `argocd` namespace | Does NOT exist |
| ArgoCD CRDs | NOT installed |
| ArgoCD pods | NOT running |
| Devpod SA cluster-admin | NO permissions |

## Root Cause

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin privileges to:
1. Create CustomResourceDefinitions (CRDs) - cluster-scoped
2. Create ClusterRole/ClusterRoleBinding - cluster-scoped
3. Create `argocd` namespace - cluster-scoped

## Solution: One-Time Cluster Admin Action

### Step 1: Apply RBAC (Cluster Admin Only)

A cluster-admin must run this command ONCE:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

This creates:
- `argocd-installer` ClusterRole with necessary permissions
- `devpod-argocd-installer` ClusterRoleBinding (binds to devpod:default SA)
- `argocd` namespace
- `moltbook` namespace

**OR** apply the alternative location:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

### Step 2: Install ArgoCD (From Devpod, After RBAC)

After the cluster-admin applies the RBAC, run from the devpod:

```bash
# Install ArgoCD from the local manifest
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# OR install from official upstream
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 3: Verify Installation

```bash
# Check ArgoCD pods are running
kubectl get pods -n argocd

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0                     1/1     Running   0          2m
# argocd-applicationset-controller-7898f7f9f-xkm2n    1/1     Running   0          2m
# argocd-dex-server-7d9d9c7f5f-abc12                  1/1     Running   0          2m
# argocd-notifications-controller-7f8f9f7f6f-def12    1/1     Running   0          2m
# argocd-redis-6c8c9f9f9f-ghi12                      1/1     Running   0          2m
# argocd-repo-server-7b8c9d9d9d-jkl12                1/1     Running   0          2m
# argocd-server-8c9d0e0e0e-mno12                     1/1     Running   0          2m
```

### Step 4: Access ArgoCD UI (Optional)

```bash
# Port-forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access at: https://localhost:8080
# Username: admin
# Password: (output from above command)
```

### Step 5: Deploy Moltbook via ArgoCD

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Alternative: Direct Installation (Cluster Admin Only)

If the cluster-admin prefers to install ArgoCD directly without RBAC:

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace moltbook

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy Moltbook Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

## Verification Commands

```bash
# Verify ArgoCD CRDs installed
kubectl get crd | grep argoproj.io

# Verify ArgoCD namespace
kubectl get namespace argocd

# Verify ArgoCD pods
kubectl get pods -n argocd

# Verify Moltbook Application
kubectl get application moltbook -n argocd
```

## Related Files

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - Alternative RBAC manifest
- `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` - Local ArgoCD installation manifest (1.8MB)
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application manifest

## Related Beads (All requesting the same action)

- mo-28ns - BLOCKER: ArgoCD installation requires cluster-admin RBAC
- mo-2dpt - ADMIN: Cluster Admin Action - Install ArgoCD
- mo-21wr - BLOCKER: ArgoCD installation requires cluster-admin RBAC
- mo-hhbp - BLOCKER: Cluster-admin needed to apply ArgoCD RBAC
- mo-17ws - CLUSTER-ADMIN ACTION: Install ArgoCD
- mo-1l3s - ADMIN: Cluster Admin Action - Apply ARGOCD_SETUP_REQUEST.yml
- And many more duplicate P0 beads

## Next Steps

1. Cluster-admin applies `ARGOCD_INSTALL_REQUEST.yml`
2. Devpod installs ArgoCD using `argocd-install.yml` or upstream manifest
3. Verify ArgoCD is running
4. Apply Moltbook ArgoCD Application
5. Close all duplicate P0 beads
