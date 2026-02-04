# Moltbook Deployment Blocker Status

## Date: 2026-02-04

## Current Status: BLOCKED - Requires Cluster Admin Action

---

## Summary

The Moltbook platform deployment is **blocked** because the devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the required cluster-admin privileges to create the `moltbook` namespace.

---

## Root Cause Analysis

### Permission Check Results
```bash
$ kubectl auth can-i create namespace
no
```

The devpod ServiceAccount cannot:
- Create namespaces (cluster-scoped resource)
- Create ClusterRole/ClusterRoleBinding resources

### Current State
| Resource | Status |
|----------|--------|
| `moltbook` namespace | Does NOT exist |
| `namespace-creator` ClusterRole | Does NOT exist |
| `devpod-namespace-creator` ClusterRoleBinding | Does NOT exist |

---

## Resolution Options (For Cluster Admins)

### Option 1: Automated Setup (Recommended)

Apply the consolidated setup manifest that creates RBAC + namespace:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

Or run the automated setup script:
```bash
/home/coder/Research/moltbook-org/k8s/setup-namespace.sh
```

**What this does:**
1. Creates `namespace-creator` ClusterRole (grants namespace creation permissions)
2. Creates `devpod-namespace-creator` ClusterRoleBinding (binds to devpod SA)
3. Creates the `moltbook` namespace

### Option 2: Minimal Namespace Creation (Quick Fix)

If you don't want to grant additional permissions, simply create the namespace:

```bash
kubectl create namespace moltbook
```

Then from devpod, use the no-namespace kustomization:
```bash
kubectl apply -k /home/coder/Research/moltbook-org/k8s/kustomization-no-namespace.yml
```

---

## After Cluster Admin Action

Once the namespace exists, deploy from the devpod:

```bash
# If namespace + RBAC were created (Option 1)
kubectl apply -k /home/coder/Research/moltbook-org/k8s/

# OR if only namespace was created (Option 2)
kubectl apply -k /home/coder/Research/moltbook-org/k8s/kustomization-no-namespace.yml
```

---

## What Gets Deployed

After namespace creation, the following resources will be deployed:

| Component | Resources |
|-----------|-----------|
| **Database** | CloudNativePG cluster, Service, Schema ConfigMap, Init Job |
| **Cache** | Redis Deployment, Service, ConfigMap |
| **API** | moltbook-api Deployment, Service, IngressRoute, ConfigMap |
| **Frontend** | moltbook-frontend Deployment, Service, IngressRoute, ConfigMap |
| **Secrets** | SealedSecrets for API, PostgreSQL superuser, DB credentials |

---

## Verification Commands

```bash
# Check if namespace exists
kubectl get namespace moltbook

# Check deployed resources
kubectl get all -n moltbook

# Check SealedSecrets
kubectl get sealedsecrets -n moltbook

# Check CNPG cluster
kubectl get cluster -n moltbook
```

---

## Related Files

| File | Purpose |
|------|---------|
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | Cluster-admin setup manifest |
| `k8s/setup-namespace.sh` | Automated setup script |
| `k8s/NAMESPACE_SETUP_README.md` | Detailed setup instructions |
| `k8s/kustomization.yml` | Full deployment (includes namespace) |
| `k8s/kustomization-no-namespace.yml` | Deployment without namespace creation |
| `k8s/argocd-application.yml` | ArgoCD Application manifest (future) |

---

## Blocker Bead

A blocker bead has been created to track this:
- **Bead ID**: `mo-1ywd`
- **Title**: "BLOCKER: Cluster Admin - Apply Moltbook namespace setup manifest"
- **Priority**: 0 (Critical)

---

## Next Steps

1. [Cluster Admin] Apply namespace setup manifest
2. [Devpod] Verify namespace exists: `kubectl get namespace moltbook`
3. [Devpod] Deploy Moltbook platform: `kubectl apply -k k8s/`
4. [Devpod] Verify deployment: `kubectl get all -n moltbook`
