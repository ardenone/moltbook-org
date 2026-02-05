# Moltbook Deployment Blocker Summary

**Task**: mo-3ttq
**Date**: 2026-02-05
**Status**: 🔴 BLOCKED - Requires cluster-admin action

---

## Current State

| Check | Status | Command Result |
|-------|--------|----------------|
| moltbook namespace | ❌ NotFound | `kubectl get namespace moltbook` - does not exist |
| ArgoCD namespace | ❌ NotFound | ArgoCD not installed |
| Manifests | ✅ Ready | All manifests in `k8s/` directory |
| Container images | ✅ Pushed | Images available in GHCR |

---

## Blocker: Missing Namespace and RBAC

The `moltbook` namespace does not exist. A cluster-admin must create it before deployment can proceed.

### Root Cause

The kustomization at `k8s/kustomization.yml` has `namespace: moltbook` but references `namespace/moltbook-namespace.yml` which creates the namespace. This creates a circular dependency - kubectl cannot apply resources to a namespace that doesn't exist yet.

### Solution Options

#### Option 1: Quick Manual (1 command, 5 seconds)

```bash
kubectl create namespace moltbook
```

Then deploy with:
```bash
kubectl apply -k k8s/
```

#### Option 2: Apply RBAC + Namespace Setup (recommended)

```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
1. `namespace-creator` ClusterRole (grants namespace creation to devpod)
2. `devpod-namespace-creator` ClusterRoleBinding
3. `moltbook` namespace

Then deploy with:
```bash
kubectl apply -k k8s/
```

---

## What Gets Deployed (After Namespace Creation)

```bash
kubectl apply -k k8s/
```

Deploys:
- **PostgreSQL**: CloudNativePG cluster
- **Redis**: Cache for sessions
- **moltbook-api**: FastAPI backend
- **moltbook-frontend**: React frontend
- **SealedSecrets**: Encrypted secrets (GitHub OAuth, DB credentials)
- **IngressRoutes**: Traefik routing for `moltbook.ardenone.com` and `api-moltbook.ardenone.com`

---

## Related Beads

- **mo-3ttq** (P1): Deploy: Complete Moltbook deployment to ardenone-cluster (this task)
- **mo-1fgm** (P1): CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- **mo-218h** (P0): ADMIN: Cluster Admin Action - Apply ArgoCD RBAC for mo-1fgm

---

## Cluster Admin Action Required

**Choose one command:**

```bash
# Quick option (just namespace)
kubectl create namespace moltbook

# Complete option (RBAC + namespace)
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

After namespace exists, the devpod will deploy automatically or on next bead execution.
