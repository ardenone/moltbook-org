# Moltbook Deployment Status - mo-saz

**Date**: 2026-02-04
**Task**: Implementation: Deploy Moltbook platform to ardenone-cluster
**Status**: ⚠️ **MANIFESTS READY - AWAITING ARGOCD INSTALLATION**

## Executive Summary

The Moltbook platform deployment is **prepared but not deployed** to ardenone-cluster. All Kubernetes manifests are ready and committed to the ardenone-cluster repository, but ArgoCD (the GitOps deployment tool) is not installed in the cluster.

## Current Status

### ✅ Completed Work

1. **Kubernetes Manifests** - 100% Complete
   - Location: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`
   - All resources defined and validated
   - SealedSecrets created for sensitive data
   - Traefik IngressRoutes configured for both domains
   - ArgoCD Application manifest ready

2. **Infrastructure Components**
   - PostgreSQL (CloudNativePG) - manifest ready
   - Redis - manifest ready
   - API Backend (Node.js/Express) - manifest ready
   - Frontend (Next.js) - manifest ready
   - Networking (IngressRoutes, Services, Middlewares) - manifest ready
   - RBAC (Role, RoleBinding) - manifest ready

3. **GitOps Configuration**
   - ArgoCD Application manifest: `argocd-application.yml`
   - Configured to monitor: `https://github.com/ardenone/ardenone-cluster.git`
   - Path: `cluster-configuration/ardenone-cluster/moltbook`
   - Auto-sync enabled with CreateNamespace=true

### ❌ Blockers

#### Blocker #1: ArgoCD Not Installed (CRITICAL)

**Status**: ArgoCD is NOT installed in ardenone-cluster

**Evidence**:
```bash
# No ArgoCD namespace
kubectl get namespace argocd
# Error: NotFound

# No ArgoCD CRDs
kubectl api-resources | grep argoproj
# Only shows Rollouts (not Application)

# No ArgoCD applications
kubectl get applications -n argocd
# Error: resource type not found
```

**Impact**: Cannot use GitOps deployment pattern. The ArgoCD Application manifest cannot be applied.

**Bead Created**: `mo-3tx` [P0] - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment

**Resolution Required**:
1. Install ArgoCD in ardenone-cluster
2. Configure ArgoCD to access ardenone-cluster repository
3. Apply the ArgoCD Application manifest

**Alternative Resolution**:
- Deploy manifests directly with `kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/`
- Note: This violates the GitOps principle but would work immediately

#### Blocker #2: Namespace Does Not Exist

**Status**: The `moltbook` namespace does not exist in ardenone-cluster

**Evidence**:
```bash
kubectl get namespace moltbook
# Error: NotFound
```

**Note**: This blocker will be automatically resolved when Blocker #1 is fixed, because the ArgoCD Application has `CreateNamespace=true` in its sync policy.

**Bead Created**: `mo-2s1` [P0] - Fix: Create moltbook namespace in ardenone-cluster

**Resolution Required** (if NOT using ArgoCD):
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

**Current Permissions Issue**:
- devpod ServiceAccount lacks cluster-scoped permissions to create namespaces
- Requires cluster-admin intervention OR ArgoCD (which has cluster-admin)

### ⚠️ Additional Considerations

#### Frontend Build Status

The frontend Docker image build status is unknown. If the image hasn't been built, the deployment will fail with ImagePullBackOff.

**Images Required**:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

**Action**: Verify images exist in GitHub Container Registry before deployment.

## Deployment Procedure (Once Blockers Resolved)

### Option A: Via ArgoCD (Recommended)

1. **Install ArgoCD** (see bead mo-3tx)
2. **Apply Application Manifest**:
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/argocd-application.yml
   ```
3. **Monitor Sync**:
   ```bash
   # ArgoCD will automatically create namespace and deploy all resources
   # Monitor via ArgoCD UI or CLI:
   argocd app get moltbook
   argocd app sync moltbook  # if not auto-synced
   ```

### Option B: Direct kubectl (Emergency/Fallback)

1. **Create Namespace** (cluster admin only):
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
   ```

2. **Deploy All Resources**:
   ```bash
   kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
   ```

3. **Verify Deployment**:
   ```bash
   kubectl get pods -n moltbook
   kubectl get svc -n moltbook
   kubectl get ingressroute -n moltbook
   ```

## Manifest Structure

```
cluster-configuration/ardenone-cluster/moltbook/
├── argocd-application.yml        # ArgoCD Application manifest
├── kustomization.yml             # Kustomization file
├── DEPLOYMENT.md                 # Deployment guide
├── README.md                     # Documentation
├── api/                          # API backend manifests
│   ├── configmap.yml
│   ├── deployment.yml
│   ├── ingressroute.yml
│   └── service.yml
├── database/                     # PostgreSQL manifests
│   ├── cluster.yml
│   ├── schema-configmap.yml
│   ├── schema-init-deployment.yml
│   └── service.yml
├── frontend/                     # Frontend manifests
│   ├── configmap.yml
│   ├── deployment.yml
│   ├── ingressroute.yml
│   └── service.yml
├── namespace/                    # Namespace and RBAC
│   ├── moltbook-namespace.yml
│   └── moltbook-rbac.yml
├── redis/                        # Redis manifests
│   ├── configmap.yml
│   ├── deployment.yml
│   └── service.yml
└── secrets/                      # SealedSecrets
    ├── moltbook-api-sealedsecret.yml
    ├── moltbook-db-credentials-sealedsecret.yml
    └── moltbook-postgres-superuser-sealedsecret.yml
```

## Access Points (Once Deployed)

- **Frontend**: https://moltbook.ardenone.com
- **API**: https://api-moltbook.ardenone.com
- **Health Check**: https://api-moltbook.ardenone.com/health

## Related Beads

**Blockers**:
- `mo-3tx` [P0] - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
- `mo-2s1` [P0] - Fix: Create moltbook namespace in ardenone-cluster

**Related**:
- `mo-saz` - Implementation: Deploy Moltbook platform to ardenone-cluster (this task)
- `mo-23p` [P1] - Task: Verify ArgoCD Application sync for Moltbook

## Conclusion

**Implementation**: ✅ Complete - All manifests ready and committed
**Deployment**: ❌ Blocked - Awaiting ArgoCD installation

The Moltbook platform is deployment-ready. All Kubernetes manifests are prepared, validated, and committed to the ardenone-cluster repository. The only remaining blocker is the installation of ArgoCD in ardenone-cluster.

Once ArgoCD is installed (tracked in bead mo-3tx), the deployment can proceed via GitOps by applying the ArgoCD Application manifest. ArgoCD will then automatically create the namespace and deploy all resources.

**Estimated Time to Deploy**: 5-10 minutes (once ArgoCD is installed)

**Next Steps**:
1. Address bead mo-3tx (Install ArgoCD)
2. Apply ArgoCD Application manifest
3. Monitor ArgoCD sync
4. Verify pods are running
5. Test external access via domains
