# Namespace Creation Status - Bead mo-3rs

**Date**: 2026-02-04
**Bead**: mo-3rs - Fix: Grant devpod namespace creation permissions or create moltbook namespace
**Status**: BLOCKED - Requires Cluster Admin Action

---

## Executive Summary

The `moltbook` namespace **cannot be created** by the devpod ServiceAccount because:
1. Namespace creation is a cluster-scoped operation
2. Devpod ServiceAccount lacks `create` permission on `namespaces` resource
3. ArgoCD is **NOT installed** on ardenone-cluster (previous assumption incorrect)

---

## Current State (Verified 2026-02-04)

### Local Cluster (ardenone-cluster)
```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl auth can-i create namespaces
no

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found

$ kubectl get namespace argocd
Error from server (NotFound): namespaces "argocd" not found
```

**Key Finding**: ArgoCD is NOT installed on ardenone-cluster. The previous deployment plan using `k8s/argocd-application.yml` with `CreateNamespace=true` will NOT work.

---

## Available Solution Options

### Option 1: Cluster Admin Creates RBAC + Namespace (Recommended)

A cluster administrator applies the consolidated manifest:

```bash
# From any machine with cluster-admin access to ardenone-cluster
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

**This manifest creates:**
1. `ClusterRole: namespace-creator` - Grants namespace creation permissions
2. `ClusterRoleBinding: devpod-namespace-creator` - Binds to devpod ServiceAccount
3. `Namespace: moltbook` - The target namespace

**Advantages:**
- One-time cluster admin action
- Enables future namespace creation without intervention
- Fully automated deployment from devpod

---

### Option 2: Cluster Admin Creates Namespace Only (Minimal)

A cluster administrator creates just the namespace:

```bash
# From any machine with cluster-admin access
kubectl create namespace moltbook
```

**Advantages:**
- Minimal cluster admin action
- No RBAC changes needed
- Devpod can deploy resources into existing namespace

**Disadvantages:**
- Future namespace creation still requires cluster admin

---

### Option 3: Deploy to apexalgo-iad Cluster (Alternative)

The apexalgo-iad cluster has a different configuration:

```bash
$ export KUBECONFIG=/home/coder/.kube/apexalgo-iad.kubeconfig
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl auth can-i create namespaces
no
```

**Status**: Same permission issue on remote cluster.

---

## Verification Commands

After cluster admin creates the namespace:

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Verify RBAC (if Option 1 was used)
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod can deploy to moltbook
kubectl auth can-i create deployment --namespace=moltbook
kubectl auth can-i create sealedsecrets.bitnami.com --namespace=moltbook
```

---

## What Gets Deployed (After Namespace Creation)

| Component | Resources | Image |
|-----------|-----------|-------|
| **Database** | CloudNativePG cluster (1 instance, 10Gi), Services, Init | `ghcr.io/cloudnative-pg/postgresql:16.3` |
| **Cache** | Redis Deployment (1 replica), Service, ConfigMap | `redis:7-alpine` |
| **API** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-api:latest` |
| **Frontend** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-frontend:latest` |
| **Secrets** | 3 SealedSecrets (API, DB, Postgres) | Pre-encrypted |

---

## Deployment Command (After Namespace Exists)

```bash
# From devpod, apply all manifests
kubectl apply -k /home/coder/Research/moltbook-org/k8s/

# Or use the no-namespace variant
kubectl apply -k /home/coder/Research/moltbook-org/k8s/kustomization-no-namespace.yml
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | **PRIMARY**: Consolidated RBAC + namespace manifest (Option 1) |
| `k8s/setup-namespace.sh` | Automated setup script |
| `k8s/NAMESPACE_SETUP_README.md` | Detailed documentation |
| `k8s/namespace/moltbook-namespace.yml` | Namespace only manifest (Option 2) |
| `k8s/namespace/devpod-namespace-creator-rbac.yml` | RBAC only manifest |
| `k8s/kustomization.yml` | Full deployment Kustomize |
| `k8s/kustomization-no-namespace.yml` | Deployment without namespace resource |

---

## Bead Tracking

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| **mo-206n** | BLOCKER: Cluster Admin required - Create moltbook namespace in ardenone-cluster | **0** | **ACTIVE** (Created by mo-3rs) |
| mo-3rs | Fix: Grant devpod namespace creation permissions or create moltbook namespace | 1 | **COMPLETED** (Created blocker bead) |
| mo-32c | Create moltbook namespace in ardenone-cluster | 1 | BLOCKED (waiting for mo-206n) |
| mo-cx8 | Deploy: Apply Moltbook manifests to ardenone-cluster | 1 | BLOCKED (waiting for namespace) |

---

## Next Steps

1. **Cluster Admin**: Apply `k8s/NAMESPACE_SETUP_REQUEST.yml` OR run `kubectl create namespace moltbook`
2. **Verify**: Namespace exists with `kubectl get namespace moltbook`
3. **Deploy**: Apply application manifests with `kubectl apply -k k8s/`

---

## Security Considerations

The RBAC manifest grants namespace creation permissions to the devpod ServiceAccount. This is appropriate for:
- Development environments
- Trusted service accounts
- Scenarios requiring self-service namespace management

For production clusters with stricter security, consider:
- Using individual namespaces per application
- Manual namespace creation by cluster admins
- More granular RBAC policies

---

**Generated for bead mo-3rs**
**Date**: 2026-02-04
**Priority**: P1 (High)
**Status**: Resolved via blocker bead mo-206n (P0)
