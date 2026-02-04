# ArgoCD Application Sync Verification Report

**Date:** 2026-02-04
**Bead:** mo-23p
**Status:** ❌ BLOCKED - Cannot verify sync due to missing RBAC permissions

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

**File:** `k8s/argocd-application.yml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/moltbook-org.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Status:** Configuration is valid ✅

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

## Critical Blocker: RBAC Not Applied ❌

### Investigation Results

**Command:** `kubectl get clusterrole namespace-creator`
```
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found
```

**Command:** `kubectl get clusterrolebinding devpod-namespace-creator`
```
Error from server (NotFound): clusterrolebindings.rbac.authorization.k8s.io "devpod-namespace-creator" not found
```

**Command:** `kubectl get role -n moltbook moltbook-deployer`
```
Error from server (Forbidden): roles.rbac.authorization.k8s.io "moltbook-deployer" is forbidden:
User "system:serviceaccount:devpod:default" cannot get resource "roles"
in API group "rbac.authorization.k8s.io" in the namespace "moltbook"
```

### Root Cause

The RBAC manifests that grant the devpod ServiceAccount permissions to deploy Moltbook have **NOT been applied to the cluster**. This creates a deployment deadlock:

1. ArgoCD needs RBAC permissions to sync resources to the moltbook namespace
2. The moltbook-rbac.yml is a namespaced Role that can only be applied AFTER the namespace exists
3. The namespace creation requires cluster-admin permissions (not available to devpod ServiceAccount)
4. The devpod-namespace-creator ClusterRole/ClusterRoleBinding has not been applied

### Required RBAC Manifests

**ClusterRole (must be applied first):**
- File: `k8s/namespace/devpod-namespace-creator-rbac.yml`
- Grants: namespace creation, RoleBinding management
- Target: ServiceAccount `system:serviceaccount:devpod:default`
- Status: ❌ Not applied to cluster

**Namespace Role (applied after namespace exists):**
- File: `k8s/namespace/moltbook-rbac.yml`
- Grants: Full resource management in moltbook namespace
- Target: ServiceAccount `system:serviceaccount:devpod:default`
- Status: ❌ Not applied to cluster (included in kustomization but cannot sync without ClusterRole)

---

## Current Cluster State

### Namespace Status

```bash
kubectl get namespace moltbook
```
**Result:** Namespace exists ✅ (empty, no resources deployed)

```bash
kubectl get pods -n moltbook
```
**Result:** No resources found in moltbook namespace

### Resource Verification

**PostgreSQL:** ❌ Not deployed (no CNPG Cluster resources)
**Redis:** ❌ Not deployed (no pods)
**API Backend:** ❌ Not deployed (no deployment)
**Frontend:** ❌ Not deployed (no deployment)
**IngressRoutes:** Cannot verify (Forbidden to list ingressroutes)

---

## Why ArgoCD Cannot Sync

ArgoCD cannot sync the application because:

1. **ArgoCD is not deployed/operational** in the cluster
   - `kubectl api-resources | grep application` returns empty
   - ArgoCD Application CRD is not installed

2. **Even if ArgoCD were running**, it would fail due to RBAC:
   - ArgoCD's ServiceAccount would lack permissions to create resources in the moltbook namespace
   - The required RoleBindings are not applied

3. **Manual deployment is also blocked**:
   - The devpod ServiceAccount cannot list/create most resources
   - Attempting `kubectl apply -k k8s/` results in Forbidden errors

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
