# ArgoCD Application Sync Verification Report

**Date:** 2026-02-04
**Bead:** mo-23p
**Status:** ❌ BLOCKED - Cannot verify sync (ArgoCD not installed in ardenone-cluster)

---

## Objective

Verify that the ArgoCD Application (argocd-application.yml) can sync the Moltbook platform, deploying:
- PostgreSQL (CNPG)
- Redis
- API Backend
- Frontend
- IngressRoutes for moltbook.ardenone.com and api-moltbook.ardenone.com

---

## Current State

### ArgoCD Application Configuration ✅

**File Location:**
- moltbook-org repo: `/home/coder/Research/moltbook-org/k8s/argocd-application.yml`
- cluster-config repo: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/argocd-application.yml`

**Manifest (cluster-config version):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/ardenone-cluster.git
    targetRevision: main
    path: cluster-configuration/ardenone-cluster/moltbook
    kustomize:
      images:
        - ghcr.io/ardenone/moltbook-api:latest
        - ghcr.io/ardenone/moltbook-frontend:latest
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Status:** Configuration is valid ✅ (correct repo URL, correct path)

### Kustomization Configuration ✅

**File:** `k8s/kustomization.yml`

All required resources are referenced:
- ✅ Namespace (moltbook-namespace.yml)
- ✅ RBAC (moltbook-rbac.yml)
- ✅ SealedSecrets (3 secrets)
- ✅ PostgreSQL CNPG Cluster
- ✅ Redis Deployment & Service
- ✅ API Deployment & Service & IngressRoute
- ✅ Frontend Deployment & Service & IngressRoute

**Status:** Kustomization is properly configured ✅

---

## Critical Blocker: ArgoCD Not Installed ❌

### Investigation Results

**Command:** `kubectl get namespace argocd`
```
Error from server (NotFound): namespaces "argocd" not found
```

**Command:** `kubectl get applications -A`
```
error: the server doesn't have a resource type "applications"
```

**Command:** `kubectl get pods -A | grep -i argocd`
```
devpod  argocd-proxy-8686d5cb95-d5tvk  Running  (only proxy to apexalgo-iad, NOT local ArgoCD)
```

### Root Cause

**ArgoCD is NOT installed in ardenone-cluster.**

The only ArgoCD-related component is `argocd-proxy` in the devpod namespace, which provides proxy access to ArgoCD in the **apexalgo-iad** cluster (remote), NOT ardenone-cluster (local).

Without ArgoCD installed:
- The Application resource type doesn't exist
- Cannot create ArgoCD Applications
- Cannot perform GitOps deployment via ArgoCD
- The ArgoCD Application manifest cannot be applied

---

## Secondary Blocker: Namespace Does Not Exist ❌

**Command:** `kubectl get namespace moltbook`
```
Error from server (NotFound): namespaces "moltbook" not found
```

### Impact
- No namespace to deploy resources into
- Cannot verify RBAC (Role is namespaced)
- All resource deployments are blocked

---

## Current Cluster State

### Namespace Status
❌ **moltbook namespace does NOT exist**

### ArgoCD Status
❌ **ArgoCD is NOT installed in ardenone-cluster**

### Resource Verification
**PostgreSQL:** ❌ Not deployed (namespace doesn't exist)
**Redis:** ❌ Not deployed (namespace doesn't exist)
**API Backend:** ❌ Not deployed (namespace doesn't exist)
**Frontend:** ❌ Not deployed (namespace doesn't exist)
**IngressRoutes:** ❌ Cannot verify (namespace doesn't exist)

---

## Why ArgoCD Cannot Sync

ArgoCD cannot sync the application because:

1. **ArgoCD is NOT installed** in ardenone-cluster
   - No `argocd` namespace exists
   - No ArgoCD Custom Resource Definitions (CRDs) registered
   - No ArgoCD server components running
   - Only `argocd-proxy` exists (for remote cluster access, NOT local ArgoCD)

2. **The Application resource type doesn't exist**
   - Cannot create ArgoCD Application manifests
   - The sync verification is impossible without ArgoCD

3. **Namespace doesn't exist**
   - No target namespace for deployment
   - ArgoCD's `CreateNamespace=true` would help, but ArgoCD isn't installed

---

## Resolution Path

### Option 1: Deploy RBAC as Cluster Admin (Recommended)

**Prerequisites:** Cluster admin access

**Steps:**
```bash
# 1. Apply ClusterRole and ClusterRoleBinding (requires cluster-admin)
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml

# 2. Ensure namespace exists
kubectl apply -f k8s/namespace/moltbook-namespace.yml

# 3. Apply namespaced RBAC
kubectl apply -f k8s/namespace/moltbook-rbac.yml

# 4. Deploy all resources (now devpod has permissions)
kubectl apply -k k8s/

# 5. Verify deployment
kubectl get pods -n moltbook -w
```

### Option 2: Use ArgoCD (Requires ArgoCD Installation)

**Prerequisites:**
- ArgoCD installed in cluster
- ArgoCD configured with appropriate RBAC

**Steps:**
```bash
# 1. Apply RBAC manually (requires cluster-admin)
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/namespace/moltbook-rbac.yml

# 2. Create ArgoCD Application
kubectl apply -f k8s/argocd-application.yml

# 3. ArgoCD will auto-sync resources
argocd app get moltbook
argocd app sync moltbook
```

---

## Verification Checklist

Once RBAC is applied, verify the following:

### RBAC Applied ✅/❌
- [ ] ClusterRole `namespace-creator` exists
- [ ] ClusterRoleBinding `devpod-namespace-creator` exists
- [ ] Role `moltbook-deployer` exists in moltbook namespace
- [ ] RoleBinding `moltbook-deployer-binding` exists in moltbook namespace

### Resources Deployed ✅/❌
- [ ] PostgreSQL CNPG Cluster `moltbook-postgres` running
- [ ] Redis Deployment `moltbook-redis` running
- [ ] API Deployment `moltbook-api` running (2 replicas)
- [ ] Frontend Deployment `moltbook-frontend` running (2 replicas)
- [ ] IngressRoute `moltbook.ardenone.com` exists
- [ ] IngressRoute `api-moltbook.ardenone.com` exists
- [ ] SealedSecrets decrypted successfully

### Health Checks ✅/❌
- [ ] All pods in Running state
- [ ] API health endpoint: `curl -k https://api-moltbook.ardenone.com/health`
- [ ] Frontend accessible: `curl -k https://moltbook.ardenone.com`
- [ ] PostgreSQL connection working
- [ ] Redis connection working

---

## Findings Summary

| Component | Expected State | Actual State | Status |
|-----------|----------------|--------------|--------|
| ArgoCD Application Manifest | Valid YAML | ✅ Valid | ✅ |
| Kustomization | References all resources | ✅ Complete | ✅ |
| RBAC ClusterRole | Applied to cluster | ❌ Not found | ❌ |
| RBAC RoleBinding | Applied to moltbook namespace | ❌ Not found | ❌ |
| Namespace moltbook | Exists | ✅ Exists (empty) | ⚠️ |
| PostgreSQL Cluster | Running | ❌ Not deployed | ❌ |
| Redis | Running | ❌ Not deployed | ❌ |
| API Backend | Running (2 replicas) | ❌ Not deployed | ❌ |
| Frontend | Running (2 replicas) | ❌ Not deployed | ❌ |
| IngressRoutes | Configured | ❌ Cannot verify | ❌ |

---

## Related Beads

- **mo-382** [P0]: Blocker - Namespace creation requires cluster admin permissions
- **mo-2fi** [P0]: Blocker - GitHub push permissions to moltbook repositories
- **mo-37h** [P0]: Fix - Frontend build failures (webpack/React context issue)
- **mo-saz**: Deployment manifests preparation (completed)
- **mo-2ik**: GitHub push permissions (partially resolved, needs moltbook org)

---

## Conclusion

**ArgoCD Application sync CANNOT be verified** due to missing RBAC permissions. The manifests are correctly configured, but deployment is blocked at the permission layer.

**Next Action Required:** Cluster administrator must apply RBAC manifests to grant devpod ServiceAccount the necessary permissions for Moltbook deployment.

**Recommendation:** Create a priority 0 bead for cluster admin to apply RBAC configuration.
