# Moltbook Deployment Blocker Summary

**Task**: mo-3ttq
**Date**: 2026-02-05
**Status**: 🔴 BLOCKED - Requires cluster-admin action
**Verified**: 2026-02-05 08:15 UTC (mo-3ttq by claude-glm-echo)

---

## Current State

| Check | Status | Command Result |
|-------|--------|----------------|
| moltbook namespace | ❌ NotFound | `kubectl get namespace moltbook` - does not exist |
| ArgoCD namespace | ❌ NotFound | ArgoCD not installed |
| namespace-creator ClusterRole | ❌ NotFound | RBAC not applied |
| devpod-namespace-creator ClusterRoleBinding | ❌ NotFound | RBAC not applied |
| devpod SA namespace creation permission | ❌ Forbidden | Cannot create namespaces |
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

### Cluster Admin Action Required (P0)
- **mo-30pg** (P0): Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) - **ACTION REQUIRED**
- **mo-5vd** (P0): Fix: Cluster-admin action - Apply RBAC for devpod namespace management (NEW - created 2026-02-05 07:05 UTC)

### ArgoCD Installation Blockers
- **mo-3ki8** (P0): BLOCKER: ArgoCD installation requires cluster-admin RBAC
- **mo-17ws** (P0): CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm
- **mo-1fgm** (P1): CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments

### Current Task
- **mo-3ttq** (P1): Deploy: Complete Moltbook deployment to ardenone-cluster (this task)

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
