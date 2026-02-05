# Moltbook Deployment Status - ardenone-cluster

**Task**: mo-3ttq - Deploy: Complete Moltbook deployment to ardenone-cluster (waiting for RBAC)
**Date**: 2026-02-05 (Updated 06:23 UTC)
**Status**: 🔴 BLOCKED - Requires cluster-admin privileges
**Latest Blocker Bead**: **mo-r55n** (P0) - Cluster-admin action required (created 2026-02-05 06:23 UTC)

---

## Executive Summary

Moltbook deployment manifests are **fully prepared and ready** in the `moltbook-org` repository. The deployment is **blocked** because:

1. **ArgoCD is NOT installed** in ardenone-cluster (see mo-1fgm, mo-218h)
2. **moltbook namespace does NOT exist** (requires cluster-admin to create)
3. **RBAC permissions NOT granted** for devpod ServiceAccount to create namespaces

### Impact

- **BLOCKS** Moltbook platform deployment
- **BLOCKS** Automated GitOps-based deployment workflow
- **Existing manifests are READY** - waiting for cluster-admin action

---

## Current State Verification

| Check | Status | Details |
|-------|--------|---------|
| argocd namespace | ❌ NotFound | ArgoCD not installed |
| moltbook namespace | ❌ NotFound | `kubectl get namespace moltbook` - does not exist |
| namespace-creator ClusterRole | ❌ Not Installed | Required for devpod to create namespaces |
| devpod-namespace-creator ClusterRoleBinding | ❌ Not Installed | Binds ClusterRole to devpod SA |
| Deployment manifests | ✅ Ready | All manifests in `k8s/` directory |
| SealedSecrets | ✅ Ready | All secrets encrypted and committed |
| Container images | ✅ Pushed | `ghcr.io/ardenone/moltbook-api:latest`, `ghcr.io/ardenone/moltbook-frontend:latest` |

---

## Deployment Manifests Inventory

### Location: `/home/coder/Research/moltbook-org/k8s/`

All manifests are **ready and committed**:

```
k8s/
├── kustomization.yml                 # Main Kustomize build
├── argocd-application.yml            # ArgoCD Application manifest (requires ArgoCD)
├── NAMESPACE_SETUP_REQUEST.yml       # Cluster RBAC + namespace (cluster-admin required)
├── namespace/
│   ├── moltbook-namespace.yml        # Namespace definition
│   ├── moltbook-rbac.yml             # Role/RoleBinding for devpod
│   └── devpod-namespace-creator-rbac.yml  # ClusterRole/ClusterRoleBinding
├── secrets/
│   ├── moltbook-api-sealedsecret.yml
│   ├── moltbook-postgres-superuser-sealedsecret.yml
│   └── moltbook-db-credentials-sealedsecret.yml
├── database/
│   ├── cluster.yml                   # CloudNativePG cluster
│   ├── service.yml
│   ├── schema-configmap.yml
│   └── schema-init-deployment.yml
├── redis/
│   ├── deployment.yml
│   ├── service.yml
│   └── configmap.yml
├── api/
│   ├── deployment.yml
│   ├── service.yml
│   ├── configmap.yml
│   └── ingressroute.yml
└── frontend/
    ├── deployment.yml
    ├── service.yml
    ├── configmap.yml
    └── ingressroute.yml
```

---

## Deployment Options

### Option 1: Manual kubectl Deployment (Recommended - No ArgoCD Required)

**Best for**: Immediate deployment without waiting for ArgoCD installation

```bash
# Step 1: Cluster Admin - Create RBAC and namespace
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml

# Step 2: Devpod - Deploy all resources
kubectl apply -k k8s/
```

**Pros:**
- Does not require ArgoCD installation
- Immediate deployment possible
- Full control over deployment process

**Cons:**
- Not GitOps (no automatic sync)
- Manual updates required

### Option 2: ArgoCD GitOps Deployment (BLOCKED - Requires ArgoCD Installation)

**Best for**: Automated GitOps workflow

```bash
# Step 1: Cluster Admin - Install ArgoCD (see mo-1fgm, mo-218h)
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Step 2: Cluster Admin - Grant devpod ArgoCD management permissions
kubectl apply -f k8s/ARGOCD_SETUP_REQUEST.yml

# Step 3: Devpod - Deploy ArgoCD Application
kubectl apply -f k8s/argocd-application.yml
```

**Pros:**
- Automated GitOps workflow
- Automatic sync with Git repository
- Self-healing and drift detection

**Cons:**
- **BLOCKED** - ArgoCD not installed
- Requires two cluster-admin actions

---

## Cluster Admin Action Required

### Action 1: Create Namespace and RBAC (30 seconds)

Run **one** of these commands:

```bash
# Option A: Apply combined manifest (RECOMMENDED)
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml

# Option B: Create namespace only (quickest)
kubectl create namespace moltbook
```

### Action 2: (Optional) Install ArgoCD for GitOps

If you want automated GitOps deployments:

```bash
# Apply ArgoCD installation
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml
```

---

## What Gets Deployed

After cluster-admin creates the namespace, running `kubectl apply -k k8s/` deploys:

### Database & Cache
- **PostgreSQL**: CloudNativePG cluster (1 primary + replicas)
- **Redis**: Redis cache for session management

### Application
- **moltbook-api**: Python FastAPI backend
- **moltbook-frontend**: React frontend (nginx)

### Configuration
- **SealedSecrets**: Encrypted secrets (GitHub OAuth, database credentials)
- **ConfigMaps**: Application configuration

### Networking
- **Services**: ClusterIP services for API and frontend
- **IngressRoutes**: Traefik routing for external access

### Ingress Routes
- **moltbook.ardenone.com** → Frontend
- **api-moltbook.ardenone.com** → API

---

## Container Images

| Component | Image | Tag |
|-----------|-------|-----|
| API | `ghcr.io/ardenone/moltbook-api` | latest (c972c39) |
| Frontend | `ghcr.io/ardenone/moltbook-frontend` | latest (c972c39) |

Both images are **pushed and ready** for deployment.

---

## Verification Commands

### After Namespace Creation

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Verify RBAC
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
```

### After Deployment

```bash
# Check all resources
kubectl get all -n moltbook

# Check deployments
kubectl get deployments -n moltbook

# Check pods
kubectl get pods -n moltbook

# Check ingress routes
kubectl get ingressroutes -n moltbook

# Check database cluster
kubectl get cluster -n moltbook
```

---

## Related Beads

### Cluster Admin Action Required (P0)
- **mo-r55n** (P0): Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) - **ACTION REQUIRED** (Latest)
- **mo-2fv7** (P0): Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq)
- **mo-1p0k** (P0): CLUSTER-ACTION: Create moltbook namespace and apply RBAC

### ArgoCD Installation Blockers
- **mo-3ki8** (P0): BLOCKER: ArgoCD installation requires cluster-admin RBAC
- **mo-17ws** (P0): CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm
- **mo-1fgm** (P1): CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments

### Current Task
- **mo-3ttq** (P1): Deploy: Complete Moltbook deployment to ardenone-cluster (this task)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ardenone-cluster                             │
│                                                                      │
│  ┌──────────────┐         ┌──────────────────────────────────────┐ │
│  │ Cluster Admin│ ──────▶ │         Namespace Creation             │ │
│  │ (Required)   │ apply   │  - NAMESPACE_SETUP_REQUEST.yml        │ │
│  └──────────────┘         │  - Creates namespace + RBAC           │ │
│                            └──────────────────────────────────────┘ │
│                            │                                          │
│  ┌──────────────┐         ▼                                         │
│  │ Devpod SA    │ ──────▶ │         moltbook namespace              │ │
│  │ (limited)   │ apply   │  ┌─────────────────────────────────┐  │ │
│  └──────────────┘         │  │ kubectl apply -k k8s/           │  │ │
│                            │  │ - SealedSecrets                 │  │ │
│                            │  │ - PostgreSQL (CNPG)             │  │ │
│                            │  │ - Redis                          │  │ │
│                            │  │ - moltbook-api                   │  │ │
│                            │  │ - moltbook-frontend              │  │ │
│                            │  │ - IngressRoutes                  │  │ │
│                            │  └─────────────────────────────────┘  │ │
│                            └──────────────────────────────────────┘ │
│                                                                      │
│  ┌──────────────┐         ┌──────────────────────────────────────┐ │
│  │ Cluster Admin│ ──────▶ │         ArgoCD (Optional)              │ │
│  │ (Optional)   │ apply   │  - argocd-install.yml                 │ │
│  └──────────────┘         │  - ARGOCD_SETUP_REQUEST.yml           │ │
│                            └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Problem: `kubectl get namespace moltbook` returns `NotFound`

**Solution**: Cluster admin needs to create the namespace:
```bash
kubectl create namespace moltbook
```

### Problem: Still getting "permissions denied" errors

**Solution**: Verify RBAC was applied:
```bash
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

### Problem: ArgoCD Application not syncing

**Solution**: ArgoCD is not installed. Either:
1. Install ArgoCD (requires cluster-admin)
2. Use manual deployment with `kubectl apply -k k8s/`

---

## Next Steps

### Immediate Path (Manual Deployment)

1. **Cluster Admin**: Create namespace
   ```bash
   kubectl create namespace moltbook
   ```

2. **Devpod**: Deploy all resources
   ```bash
   kubectl apply -k /home/coder/Research/moltbook-org/k8s/
   ```

3. **Verify**: Check pods are running
   ```bash
   kubectl get pods -n moltbook
   ```

### GitOps Path (Requires ArgoCD Installation)

1. **Cluster Admin**: Install ArgoCD
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
   ```

2. **Cluster Admin**: Apply RBAC
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
   ```

3. **Devpod**: Deploy ArgoCD Application
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
   ```

---

**Last Updated**: 2026-02-05 06:15 UTC
**Verified by**: mo-3ttq (claude-sonnet-bravo worker)
**Status**: 🔴 BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Estimated Time**: 2 minutes (one-time setup for manual deployment)

**Blocker Beads Created**:
- mo-r55n (P0) - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq) (Latest - 2026-02-05 06:23 UTC)
- mo-2fv7 (P0) - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment (mo-3ttq)
- mo-1p0k (P0) - CLUSTER-ACTION: Create moltbook namespace and apply RBAC

## Verification Log (Latest)

| Timestamp | Check | Result | Verified By |
|-----------|-------|--------|-------------|
| 2026-02-05 06:23 UTC | Namespace `moltbook` | ❌ NotFound | mo-3ttq (claude-glm-alpha) |
| 2026-02-05 06:23 UTC | Devpod SA create namespace | ❌ Forbidden | mo-3ttq (claude-glm-alpha) |
| 2026-02-05 06:23 UTC | Blocker bead created | ✅ mo-r55n (P0) | mo-3ttq (claude-glm-alpha) |
| 2026-02-05 08:25 UTC | Namespace `moltbook` | ❌ NotFound | mo-3ttq (claude-glm-foxtrot) |
| 2026-02-05 08:25 UTC | ArgoCD namespace | ❌ NotFound | mo-3ttq (claude-glm-foxtrot) |
| 2026-02-05 08:25 UTC | Devpod SA create namespace | ❌ Forbidden | mo-3ttq (claude-glm-foxtrot) |
| 2026-02-05 08:25 UTC | Blocker verified | ✅ mo-1p0k (P0) confirmed | mo-3ttq (claude-glm-foxtrot) |
| 2026-02-05 08:15 UTC | Namespace `moltbook` | ❌ NotFound | mo-3ttq (claude-glm-echo) |
| 2026-02-05 08:15 UTC | Namespace `argocd` | ❌ NotFound | mo-3ttq (claude-glm-echo) |
| 2026-02-05 08:15 UTC | Devpod SA create namespace | ❌ Forbidden | mo-3ttq (claude-glm-echo) |
| 2026-02-05 06:30 UTC | Namespace `moltbook` | ❌ NotFound | mo-3ttq (claude-sonnet-bravo) |
| 2026-02-05 06:30 UTC | Namespace `argocd` | ❌ NotFound | mo-3ttq (claude-sonnet-bravo) |
| 2026-02-05 06:30 UTC | Devpod SA create namespace | ❌ Forbidden | mo-3ttq (claude-sonnet-bravo) |
| 2026-02-05 06:07 UTC | Namespace `moltbook` | ❌ NotFound | mo-3ttq (claude-glm-alpha) |
| 2026-02-05 06:07 UTC | Namespace `argocd` | ❌ NotFound | mo-3ttq (claude-glm-alpha) |
| 2026-02-05 06:07 UTC | Multiple blocker beads verified | ✅ Confirmed | mo-3ttq (claude-glm-alpha) |
