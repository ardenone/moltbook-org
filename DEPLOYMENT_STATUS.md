# Moltbook Deployment Status

**Last Updated**: 2026-02-04 15:26 UTC
**Bead**: mo-saz
**Status**: ✅ Manifests Ready - Blocked on Namespace Creation Permissions (mo-3o6)

## Summary

All Kubernetes manifests for deploying Moltbook platform to ardenone-cluster are complete, validated, and ready for deployment. Infrastructure verification confirms CNPG and Sealed-secrets operators are running. The only blocker is namespace creation permissions - a request file has been prepared for cluster administrators.

## ✅ Completed

### 1. Infrastructure Verification

- ✅ **CNPG Operator**: Installed and running (`cnpg-system` namespace)
  - Version: CloudNativePG
  - Pod: `cnpg-ardenone-cluster-cloudnative-pg-6f777c6778-d5x4p` (Running, 34h uptime)
- ✅ **Sealed Secrets Controller**: Installed and running (`sealed-secrets` namespace)
  - Pods: 2/2 running
  - CRD: `sealedsecrets.bitnami.com` available
- ✅ **Traefik Ingress**: Verified available in `traefik` namespace
- ✅ **Storage**: local-path provisioner available

### 2. Kubernetes Manifests

All manifests are in the `k8s/` directory and validated with kustomize (820 lines):

- ✅ **Namespace**: `moltbook` namespace with proper labels
  - Request file: `k8s/NAMESPACE_REQUEST.yml` (requires cluster admin)
  - Alternative kustomization: `k8s/kustomization-no-namespace.yml`
- ✅ **PostgreSQL**: CloudNativePG (CNPG) cluster configuration
  - 1 instance (can scale to 3)
  - Proper storage configuration (10Gi, local-path)
  - Database initialization with UUID extension
  - Schema ConfigMap included
- ✅ **Redis**: Optional service for rate limiting
  - Single replica deployment
  - Service exposed as `moltbook-redis:6379`
- ✅ **API Backend**: Node.js Express API
  - 2 replicas
  - Health checks configured
  - Resource limits set
  - Init container for database migrations
- ✅ **Frontend**: Next.js web application
  - 2 replicas
  - Health checks configured
  - Resource limits set
- ✅ **Ingress**: Traefik IngressRoutes
  - Frontend: `moltbook.ardenone.com`
  - API: `api-moltbook.ardenone.com`
  - Let's Encrypt TLS certificates
  - CORS middleware for API
  - Security headers middleware for frontend
  - Rate limiting middleware for API

### 3. Secrets Management

**SealedSecrets Created** (production-ready):
- ✅ `k8s/secrets/moltbook-api-sealedsecret.yml` - API secrets including JWT, DB connection, Twitter OAuth
- ✅ `k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml` - PostgreSQL superuser credentials
- ✅ `k8s/secrets/moltbook-db-credentials-sealedsecret.yml` - Database application user credentials

All secrets are encrypted using sealed-secrets controller and safe to commit to git. The sealed-secrets controller will automatically decrypt them when applied to the cluster.

**Templates Available** (for reference):
- ✅ `k8s/secrets/moltbook-api-secrets-template.yml`
- ✅ `k8s/secrets/moltbook-db-credentials-template.yml`
- ✅ `k8s/secrets/postgres-superuser-secret-template.yml`
- ✅ `k8s/secrets/README.md` - Complete documentation

### 4. Deployment Files

- ✅ `k8s/kustomization.yml` - Main kustomization file (standard deployment)
- ✅ `k8s/kustomization-no-namespace.yml` - Alternative without namespace resource (for use after namespace is pre-created)
- ✅ `k8s/NAMESPACE_REQUEST.yml` - Namespace creation request for cluster admin
- ✅ `k8s/argocd-application.yml` - ArgoCD application manifest (for future use when ArgoCD is installed)

### 5. Documentation

Created comprehensive guides:
- ✅ `DEPLOYMENT_GUIDE.md` - Complete step-by-step deployment guide
- ✅ `DEPLOYMENT.md` - Original technical documentation
- ✅ `DEPLOYMENT_SUMMARY.md` - High-level overview

### 6. Git Repository

- ✅ All changes committed to git
- ✅ Submodules properly configured (api, moltbook-frontend)
- ✅ .gitignore configured to prevent accidental secret commits

## 🚨 Current Blocker

### Namespace Creation Permissions

**Blocker Bead**: `mo-3o6` - "Fix: Grant devpod ServiceAccount namespace creation permissions"

**Status**: 🚨 **CRITICAL BLOCKER**

The `system:serviceaccount:devpod:default` ServiceAccount lacks cluster-scoped permissions to create namespaces.

**Error**:
```
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```

**Solutions**:

1. **Option A: Cluster Admin Creates Namespace** (Recommended)
   ```bash
   kubectl apply -f k8s/NAMESPACE_REQUEST.yml
   ```
   After namespace is created, deploy with:
   ```bash
   kubectl apply -k k8s/
   ```

2. **Option B: Grant ClusterRole to devpod ServiceAccount**
   Create ClusterRole with namespace creation permissions and bind to devpod SA.

3. **Option C: Use ArgoCD** (Future)
   Install ArgoCD which has cluster-admin permissions and can create namespaces automatically.

## 📋 Deployment Steps (Post-Blocker Resolution)

Once the `moltbook` namespace is created by cluster admin:

### Step 1: Apply All Resources
```bash
kubectl apply -k k8s/
```

This will deploy:
1. Namespace (if using standard kustomization.yml)
2. RBAC roles and bindings
3. SealedSecrets (auto-decrypted by sealed-secrets controller)
4. PostgreSQL cluster (CNPG)
5. Redis deployment
6. API backend with init container for migrations
7. Frontend application
8. Ingress routes for external access

### Step 2: Monitor Deployment
```bash
# Watch pod status
kubectl get pods -n moltbook -w

# Check CNPG cluster
kubectl get cluster -n moltbook

# Check secrets (should be auto-decrypted)
kubectl get secrets -n moltbook
```

### Step 3: Verify PostgreSQL
```bash
# Wait for PostgreSQL cluster to be ready
kubectl wait --for=condition=Ready cluster/moltbook-postgres -n moltbook --timeout=300s

# Check cluster status
kubectl get cluster -n moltbook -o wide
```

### Step 4: Verify Services
```bash
# Check all services
kubectl get svc -n moltbook

# Check ingress routes
kubectl get ingressroute -n moltbook
```

### Step 5: Test External Access
```bash
# Test frontend (after DNS propagates)
curl -I https://moltbook.ardenone.com

# Test API
curl https://api-moltbook.ardenone.com/health
```

## 📦 Docker Images

The manifests reference these images:
- `ghcr.io/moltbook/api:latest`
- `ghcr.io/moltbook/frontend:latest`

**Status**:
- ✅ GitHub Actions workflow exists at `.github/workflows/build-push.yml`
- ✅ Both subdirectories have production-ready Dockerfiles with multi-stage builds
- 🔨 **BLOCKED**: Local image builds fail due to Docker Hub rate limits (anonymous pulls)
- **Solution**: Push code changes to GitHub to trigger the workflow (GitHub Actions has no rate limits)

**GitHub Actions Workflow**:
The existing workflow automatically builds and pushes images when:
- Changes are pushed to the `main` branch
- Changes are made to `api/**` or `moltbook-frontend/**` directories
- Workflow is manually triggered via `workflow_dispatch`

**Workaround**: After resolving RBAC and committing changes, the push to main will trigger automatic image builds.

### 3. Deployment to Cluster

**Prerequisites**:
1. ✅ All manifests validated and ready
2. 🔨 RBAC permissions configured (Blocker: mo-3r7)
3. 🔨 Docker images built and pushed to ghcr.io (Blocker: mo-jgo)

**Deployment Steps** (once blockers resolved):

1. **Apply Namespace**:
   ```bash
   kubectl apply -f k8s/namespace/moltbook-namespace.yml
   ```

2. **Apply ArgoCD Application**:
   ```bash
   kubectl apply -f k8s/argocd-application.yml
   ```

2. **Monitor Deployment**:
   ```bash
   # Watch ArgoCD sync status
   kubectl get application moltbook -n argocd -w

   # Watch pod status
   kubectl get pods -n moltbook -w
   ```

3. **Verify Services**:
   ```bash
   # Check CNPG cluster
   kubectl get cluster -n moltbook

   # Check all services
   kubectl get svc,ingressroute -n moltbook
   ```

4. **Test External Access**:
   ```bash
   # Test frontend
   curl -I https://moltbook.ardenone.com

   # Test API
   curl https://api-moltbook.ardenone.com/health
   ```

### 4. Production Secrets

**Before production deployment**:
1. Generate strong secrets:
   ```bash
   JWT_SECRET=$(openssl rand -base64 32)
   DB_PASSWORD=$(openssl rand -base64 24)
   POSTGRES_PASSWORD=$(openssl rand -base64 24)
   ```

2. Create SealedSecrets or use external secret manager

3. Remove secretGenerator from kustomization.yml

4. Apply sealed secrets:
   ```bash
   kubectl apply -f k8s/secrets/moltbook-api-sealedsecret.yml
   kubectl apply -f k8s/secrets/moltbook-db-credentials-sealedsecret.yml
   kubectl apply -f k8s/secrets/postgres-superuser-sealedsecret.yml
   ```

See `k8s/secrets/README.md` for complete instructions.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ardenone-cluster                      │
│                                                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Namespace: moltbook                   │  │
│  │                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐│  │
│  │  │   Frontend   │  │     API      │  │  Redis   ││  │
│  │  │  (Next.js)   │  │  (Node.js)   │  │          ││  │
│  │  │   2 replicas │  │   2 replicas │  │ 1 replica││  │
│  │  └──────┬───────┘  └──────┬───────┘  └────┬─────┘│  │
│  │         │                  │                │      │  │
│  │         │                  └────────────────┘      │  │
│  │         │                           │              │  │
│  │         │                  ┌────────▼────────┐    │  │
│  │         │                  │   PostgreSQL    │    │  │
│  │         │                  │     (CNPG)      │    │  │
│  │         │                  │    1 instance   │    │  │
│  │         │                  └─────────────────┘    │  │
│  └─────────┼──────────────────────────────────────────┘  │
│            │                                              │
│  ┌─────────▼──────────────────────────────────────────┐  │
│  │           Traefik Ingress Controller                │  │
│  │  ┌────────────────────┐  ┌────────────────────┐   │  │
│  │  │ moltbook.ardenone  │  │ api-moltbook       │   │  │
│  │  │      .com          │  │  .ardenone.com     │   │  │
│  │  │ (Frontend)         │  │     (API)          │   │  │
│  │  └────────────────────┘  └────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
│            │                           │                   │
└────────────┼───────────────────────────┼──────────────────┘
             │                           │
             ▼                           ▼
        Let's Encrypt                Let's Encrypt
         (TLS Cert)                   (TLS Cert)
```

## Configuration Details

### Domains
- **Frontend**: https://moltbook.ardenone.com
- **API**: https://api-moltbook.ardenone.com

### Database Connection
- **Service**: `moltbook-postgres-rw.moltbook.svc.cluster.local:5432`
- **Database**: `moltbook`
- **User**: `moltbook` (app user, CNPG auto-created)

### Resource Allocation
- **API**: 100m-500m CPU, 128Mi-512Mi memory per pod
- **Frontend**: 100m-500m CPU, 128Mi-512Mi memory per pod
- **Redis**: 50m-200m CPU, 64Mi-256Mi memory
- **PostgreSQL**: Managed by CNPG operator

### Security
- ✅ Non-root containers
- ✅ Health checks configured
- ✅ TLS/HTTPS enabled via Let's Encrypt
- ✅ CORS configured
- ✅ Rate limiting enabled
- ✅ Security headers configured
- ⚠️ Secrets need to be properly secured for production

## References

- **Manifests**: `/home/coder/Research/moltbook-org/k8s/`
- **API Source**: `/home/coder/Research/moltbook-org/api/`
- **Frontend Source**: `/home/coder/Research/moltbook-org/moltbook-frontend/`
- **ArgoCD Application**: `k8s/argocd-application.yml`
- **Documentation**: `DEPLOYMENT_GUIDE.md`

## Next Steps (Priority Order)

1. **CRITICAL** (`mo-p0w`): Install ArgoCD in ardenone-cluster
2. **CRITICAL** (`mo-1kr`): Fix namespace creation permissions OR pre-create namespace
3. **CRITICAL** (`mo-jgo`): Resolve Docker Hub rate limit issue (for local builds)
4. **High**: Push code to trigger GitHub Actions workflow for image builds
5. **High**: Apply namespace and ArgoCD application to cluster
6. **Medium**: Verify deployment and test all services
7. **Low**: Replace development secrets with SealedSecrets for production
8. **Low**: Set up monitoring and alerting for the platform

## Notes

- The Job manifest (`k8s/database/schema-init-job.yml`) was intentionally NOT removed from the repository as it may be useful for reference, but it's excluded from kustomization.yml to follow GitOps best practices
- Database migrations are handled by an init container in the API deployment, which is idempotent and ArgoCD-compatible
- The kustomize build generates development secrets automatically - these MUST be replaced for production use
- All manifests have been validated with `kubectl kustomize` - 658 lines of generated YAML

## Success Criteria

✅ All manifests validated
✅ Kustomization builds successfully
✅ ArgoCD application manifest ready
✅ Documentation complete
✅ GitHub Actions workflow configured
✅ RBAC manifest created for moltbook namespace
🚨 **CRITICAL BLOCKER**: ArgoCD not installed (mo-p0w)
🔨 **BLOCKED**: Namespace creation permissions (mo-1kr)
🔨 **BLOCKED**: Docker images (mo-jgo)
⏳ Namespace creation
⏳ ArgoCD application deployment
⏳ Deployment verification
⏳ Production secrets configuration
