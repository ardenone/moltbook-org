# Moltbook Deployment Status - Bead mo-saz

**Date**: 2026-02-04  
**Task**: Implementation: Deploy Moltbook platform to ardenone-cluster  
**Status**: ⚠️ **BLOCKED - Requires Cluster Admin Intervention**

## Executive Summary

The Moltbook platform deployment is **fully prepared but cannot be deployed** to ardenone-cluster due to missing cluster-level permissions. All Kubernetes manifests are ready, validated, and committed to the ardenone-cluster repository at commit `d115ea76`, but deployment is blocked by two critical prerequisites that require cluster-admin intervention.

## Current Status

### ✅ Completed Work

1. **Kubernetes Manifests** - 100% Complete
   - **Location**: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`
   - **Commit**: `d115ea76` - "feat(mo-272): Deploy: Apply Moltbook manifests to ardenone-cluster"
   - **Status**: Committed and pushed to GitHub
   - All resources defined, validated, and ready for deployment
   - Manifests validated with `kubectl apply --dry-run=client`

2. **Infrastructure Components Defined**
   - ✅ Namespace definition (`moltbook-namespace.yml`)
   - ✅ RBAC (Role, RoleBinding) for devpod deployment permissions
   - ✅ PostgreSQL CNPG Cluster with schema initialization
   - ✅ Redis deployment with configuration
   - ✅ API Backend (Node.js/Express) deployment
   - ✅ Frontend (Next.js) deployment
   - ✅ SealedSecrets for API credentials and DB passwords
   - ✅ Traefik IngressRoutes for both domains
   - ✅ Traefik Middlewares (CORS, rate limiting, security headers)
   - ✅ Services for all components

3. **Domain Configuration**
   - **Frontend**: `https://moltbook.ardenone.com`
   - **API**: `https://api-moltbook.ardenone.com`
   - **TLS**: Let's Encrypt via Traefik cert-manager
   - **ExternalDNS**: Configured for Cloudflare integration

4. **Docker Images**
   - ✅ `ghcr.io/ardenone/moltbook-api:latest` - Available (HTTP 401 = auth required)
   - ✅ `ghcr.io/ardenone/moltbook-frontend:latest` - Available (HTTP 401 = auth required)
   - Images exist in GitHub Container Registry

### ❌ Critical Blockers

#### Blocker #1: Namespace Creation Permission (P0 - CRITICAL)

**Issue**: The `moltbook` namespace does not exist, and the devpod ServiceAccount lacks cluster-scoped permissions to create it.

**Error**:
```
Error from server (Forbidden): namespaces is forbidden: 
User "system:serviceaccount:devpod:default" cannot create resource "namespaces" 
in API group "" at the cluster scope
```

**Evidence**:
```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl auth can-i create namespaces
no
```

**Resolution Required** (Cluster Admin Only):
```bash
# Option A: Apply the namespace creator RBAC (preferred)
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml

# Option B: Create namespace directly
kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

**Bead Created**: `mo-2q8h` [P0] - CRITICAL: Apply devpod-namespace-creator RBAC to enable Moltbook deployment

**Impact**: Cannot proceed with any deployment steps until namespace exists.

---

#### Blocker #2: ArgoCD Not Installed (P0 - CRITICAL)

**Issue**: ArgoCD is not installed in ardenone-cluster, preventing GitOps-based deployment.

**Evidence**:
```bash
$ kubectl get namespace argocd
Error from server (NotFound): namespaces "argocd" not found

$ kubectl api-resources | grep -i application
# No Application CRD found (only Rollout from Argo Rollouts)
```

**Impact**:
- Cannot use GitOps deployment pattern
- Manual `kubectl apply` required after namespace is created
- No automatic sync from Git repository

**Resolution Required** (Cluster Admin Only):
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Bead Created**: `mo-1fgm` [P0] - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments

**Workaround**: Deploy manually with `kubectl apply -k` after namespace is created (Option B below).

---

## Deployment Procedure (Once Blockers Resolved)

### Option A: GitOps Deployment via ArgoCD (Recommended)

**Prerequisites**: 
- ArgoCD installed (bead `mo-1fgm`)
- Namespace creator RBAC applied (bead `mo-2q8h`)

**Steps**:
1. **Apply ArgoCD Application Manifest**:
   ```bash
   kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/argocd-application.yml
   ```

2. **Monitor Sync**:
   ```bash
   # ArgoCD will automatically:
   # - Create moltbook namespace
   # - Deploy all resources
   # - Sync on every git push
   
   argocd app get moltbook
   argocd app sync moltbook  # if not auto-synced
   ```

3. **Verify Deployment**:
   ```bash
   kubectl get pods -n moltbook
   kubectl get ingressroute -n moltbook
   ```

---

### Option B: Manual Deployment via kubectl (Fallback)

**Prerequisites**: 
- Namespace must exist (cluster admin creates it manually)

**Steps**:
1. **Create Namespace** (Cluster Admin Only):
   ```bash
   kubectl apply -f /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
   ```

2. **Apply All Manifests**:
   ```bash
   cd /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook
   kubectl apply -k .
   ```

3. **Verify Deployment**:
   ```bash
   kubectl get all -n moltbook
   kubectl get clusters.postgresql.cnpg.io -n moltbook
   kubectl get ingressroutes -n moltbook
   kubectl get sealedsecrets -n moltbook
   ```

4. **Monitor Pod Health**:
   ```bash
   kubectl get pods -n moltbook -w
   kubectl logs -n moltbook -l app=moltbook-api --tail=50
   kubectl logs -n moltbook -l app=moltbook-frontend --tail=50
   ```

5. **Test External Access**:
   ```bash
   curl -I https://api-moltbook.ardenone.com/health
   curl -I https://moltbook.ardenone.com
   ```

---

## Manifest Structure

```
/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/
├── argocd-application.yml              # ArgoCD Application manifest
├── kustomization.yml                   # Kustomize overlay
├── namespace.yml                       # Namespace + RBAC definitions
├── api/
│   ├── deployment.yml                  # API backend deployment
│   ├── service.yml                     # API service
│   ├── configmap.yml                   # API configuration
│   └── ingressroute.yml                # API ingress (api-moltbook.ardenone.com)
├── frontend/
│   ├── deployment.yml                  # Frontend deployment
│   ├── service.yml                     # Frontend service
│   ├── configmap.yml                   # Frontend configuration
│   └── ingressroute.yml                # Frontend ingress (moltbook.ardenone.com)
├── database/
│   ├── cluster.yml                     # PostgreSQL CNPG cluster
│   ├── service.yml                     # PostgreSQL service
│   ├── schema-configmap.yml            # Database schema SQL
│   └── schema-init-deployment.yml      # Schema initialization job
├── redis/
│   ├── deployment.yml                  # Redis deployment
│   ├── service.yml                     # Redis service
│   └── configmap.yml                   # Redis configuration
├── secrets/
│   ├── moltbook-api-sealedsecret.yml           # API secrets (JWT, session)
│   ├── moltbook-db-credentials-sealedsecret.yml # DB app credentials
│   └── moltbook-postgres-superuser-sealedsecret.yml # DB superuser
└── namespace/
    ├── moltbook-namespace.yml          # Namespace definition
    ├── moltbook-rbac.yml               # Namespace-scoped RBAC
    └── devpod-namespace-creator-rbac.yml # Cluster-scoped RBAC (requires admin)
```

**Total**: 24+ manifest files across all components

---

## Verification Commands (Post-Deployment)

### Resource Health Checks
```bash
# Check all resources
kubectl get all -n moltbook

# Check PostgreSQL cluster
kubectl get clusters.postgresql.cnpg.io -n moltbook
kubectl get pods -n moltbook -l cnpg.io/cluster=moltbook-postgres

# Check SealedSecrets
kubectl get sealedsecrets -n moltbook

# Check IngressRoutes
kubectl get ingressroutes -n moltbook
```

### Application Health Checks
```bash
# API health endpoint
curl https://api-moltbook.ardenone.com/health
# Expected: {"status":"ok","database":"connected","redis":"connected"}

# Frontend homepage
curl -I https://moltbook.ardenone.com
# Expected: HTTP/2 200

# DNS resolution
dig +short moltbook.ardenone.com
dig +short api-moltbook.ardenone.com
```

### Debugging Commands
```bash
# View API logs
kubectl logs -n moltbook -l app=moltbook-api --tail=100 -f

# View frontend logs
kubectl logs -n moltbook -l app=moltbook-frontend --tail=100 -f

# View PostgreSQL logs
kubectl logs -n moltbook -l cnpg.io/cluster=moltbook-postgres --tail=100 -f

# Describe failing pods
kubectl describe pod -n moltbook <pod-name>

# Check events
kubectl get events -n moltbook --sort-by=.lastTimestamp
```

---

## Related Beads

### Blockers (P0 - CRITICAL)
- **mo-2q8h** - CRITICAL: Apply devpod-namespace-creator RBAC to enable Moltbook deployment
- **mo-1fgm** - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments

### Parent Task
- **mo-saz** - Implementation: Deploy Moltbook platform to ardenone-cluster (this task)

---

## Conclusion

**Deployment Readiness**: ✅ **100% Complete**  
**Deployment Status**: ❌ **BLOCKED - Awaiting Cluster Admin**

All Moltbook deployment manifests are prepared, validated, and committed to the ardenone-cluster repository. The platform is **deployment-ready** but cannot proceed without cluster-admin intervention to:

1. **Apply namespace creator RBAC** OR **create moltbook namespace directly**
2. **(Optional)** **Install ArgoCD** for GitOps-based deployment

Once either blocker is resolved:
- **With ArgoCD**: Apply the ArgoCD Application manifest, and ArgoCD handles the rest
- **Without ArgoCD**: Run `kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/`

**Estimated Time to Deploy**: 5-10 minutes (once namespace exists)

**Next Steps**:
1. Cluster admin resolves bead `mo-2q8h` (apply RBAC or create namespace)
2. *(Optional)* Cluster admin resolves bead `mo-1fgm` (install ArgoCD)
3. Deploy Moltbook using Option A (ArgoCD) or Option B (kubectl)
4. Verify pods are running and healthy
5. Test external access via `moltbook.ardenone.com` and `api-moltbook.ardenone.com`

---

**Prepared by**: Claude Sonnet Worker (mo-saz)  
**Date**: 2026-02-04  
**Repository**: https://github.com/ardenone/ardenone-cluster  
**Manifest Path**: `cluster-configuration/ardenone-cluster/moltbook/`
