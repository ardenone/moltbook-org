# Task mo-1rgl Status: Fix: RBAC for moltbook namespace creation

**Task ID**: mo-1rgl
**Title**: Fix: RBAC for moltbook namespace creation
**Status**: BLOCKED - Requires cluster-admin RBAC
**Date**: 2026-02-05 13:10 UTC
**Worker**: claude-glm-hotel

---

## Executive Summary

Task mo-1rgl ("Fix: RBAC for moltbook namespace creation") was executed from a devpod but **requires cluster-admin action** to complete. The `moltbook` namespace does not exist and the devpod ServiceAccount lacks the cluster-admin privileges required to create namespaces or apply cluster-scoped RBAC.

**Resolution**: Created bead **mo-3kx0 (P0)** to track the cluster-admin action required. A cluster-admin must apply the RBAC manifest from `k8s/NAMESPACE_SETUP_REQUEST.yml`.

---

## Current State (2026-02-05 13:10 UTC)

| Component | Status | Details |
|-----------|--------|---------|
| moltbook namespace | NOT FOUND | Does not exist |
| ClusterRole `namespace-creator` | NOT FOUND | Does not exist |
| ClusterRoleBinding `devpod-namespace-creator` | NOT FOUND | **BLOCKER** - Cannot create from devpod |
| Devpod SA permissions | INSUFFICIENT | Cannot create namespaces, ClusterRoles, or ClusterRoleBindings |

---

## Verification Results

```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found

$ kubectl get clusterrolebinding devpod-namespace-creator
Error from server (NotFound): clusterrolebindings.rbac.authorization.k8s.io "devpod-namespace-creator" not found

$ kubectl auth can-i create namespace
no

$ kubectl auth can-i create clusterrole
no

$ kubectl auth can-i create clusterrolebinding
no
```

---

## Required Cluster-Admin Action

A cluster-admin (with direct access to ardenone-cluster) must run **one** of the following:

### Option 1: Apply Combined Setup Manifest (Recommended)

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

### Option 2: Run Setup Script

```bash
/home/coder/Research/moltbook-org/k8s/setup-namespace.sh
```

### Option 3: Manual kubectl Commands

```bash
# Create RBAC
kubectl create clusterrole namespace-creator \
  --verb=create,get,list,watch \
  --resource=namespace

kubectl create clusterrolebinding devpod-namespace-creator \
  --clusterrole=namespace-creator \
  --serviceaccount=devpod:default

# Create namespace
kubectl create namespace moltbook
```

---

## After Cluster-Admin Action

Once the RBAC is applied and namespace exists, from the devpod run:

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Deploy all Moltbook resources
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| **mo-3kx0** | **BLOCKER: Cluster-admin required - Apply RBAC for moltbook namespace creation (mo-1rgl)** | **P0** | **OPEN** |
| mo-1rgl | Fix: RBAC for moltbook namespace creation | P1 | BLOCKED (waiting for mo-3kx0) |

---

## Files Referenced

1. **k8s/NAMESPACE_SETUP_REQUEST.yml** - Combined RBAC + namespace setup manifest
2. **k8s/setup-namespace.sh** - Automated setup script
3. **k8s/CLUSTER_ADMIN_README.md** - Detailed cluster admin instructions
4. **k8s/CLUSTER_ADMIN_ACTION_REQUEST.md** - Comprehensive setup documentation

---

## Deployment Architecture

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance, 10Gi)
  ├─ moltbook-redis (Deployment, 1 replica)
  ├─ moltbook-db-init (Deployment, 1 replica)
  ├─ moltbook-api (Deployment, 2 replicas)
  └─ moltbook-frontend (Deployment, 2 replicas)
```

---

## Next Steps

1. **Cluster-admin applies RBAC** (mo-3kx0)
2. **Devpod verifies namespace** exists
3. **Deploy Moltbook** via `kubectl apply -k k8s/`
4. **Verify deployment** (pods, services, ingress)

---

**Last Updated**: 2026-02-05 13:10 UTC
**Status**: BLOCKED - Awaiting cluster-admin action (mo-3kx0)
**Priority**: P0 (Critical)
