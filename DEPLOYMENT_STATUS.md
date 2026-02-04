# Moltbook Deployment Status

**Last Updated**: 2026-02-04 15:23 UTC
**Bead**: mo-saz
**Status**: ✅ Deployment Manifests Complete - BLOCKED on ArgoCD Installation (mo-3ca) and Namespace Permissions (mo-3rp)

## Summary

The Kubernetes manifests for deploying Moltbook platform to ardenone-cluster have been prepared and committed. All configurations are in place using GitOps best practices with ArgoCD.

## ✅ Completed

### 1. Kubernetes Manifests

All manifests are in the `k8s/` directory and validated with kustomize:

- ✅ **Namespace**: `moltbook` namespace with proper labels
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

### 2. Secrets Management

**Development Secrets** (via kustomize secretGenerator):
- Automatic secret generation for development
- Includes PostgreSQL superuser, app user, and API secrets
- **⚠️ Production**: Must be replaced with SealedSecrets or external secret manager

**Templates Created**:
- ✅ `k8s/secrets/moltbook-api-secrets-template.yml` - API secrets including JWT and DB connection
- ✅ `k8s/secrets/moltbook-db-credentials-template.yml` - Database application user credentials
- ✅ `k8s/secrets/postgres-superuser-secret-template.yml` - PostgreSQL superuser credentials
- ✅ `k8s/secrets/db-connection-secret-template.yml` - Database connection string
- ✅ `k8s/secrets/README.md` - Complete documentation for creating SealedSecrets
- All templates include detailed instructions for generating strong secrets and using kubeseal

### 3. ArgoCD Application

- ✅ Application manifest: `k8s/argocd-application.yml`
- Automated sync enabled
- Prune and self-heal enabled
- Targets the main branch of moltbook-org repository

### 4. Documentation

Created comprehensive guides:
- ✅ `DEPLOYMENT_GUIDE.md` - Complete step-by-step deployment guide
- ✅ `DEPLOYMENT.md` - Original technical documentation
- ✅ `DEPLOYMENT_SUMMARY.md` - High-level overview

### 5. Git Repository

- ✅ All changes committed to git (commit 452b094)
- ✅ Submodules properly configured (api, moltbook-frontend)
- ✅ .gitignore configured to prevent accidental secret commits

## 🔨 Remaining Work & Blockers

### 1. ArgoCD Installation (CRITICAL)

**Blocker Bead**: `mo-3ca` - "CRITICAL: Install ArgoCD in ardenone-cluster"

**Status**: 🚨 **CRITICAL BLOCKER**

ArgoCD is not installed in ardenone-cluster. The manifests are designed for GitOps deployment via ArgoCD.

**Verification**:
```bash
$ kubectl get pods -n argocd
No resources found in argocd namespace.
```

**Required Actions**:
1. Install ArgoCD operator/controller in ardenone-cluster
2. Configure ArgoCD to access Git repositories
3. Apply ArgoCD Application manifest

**Without ArgoCD**, alternative deployment requires cluster-admin permissions.

### 1.1 RBAC Permissions

**Blocker Bead**: `mo-3rp` - "CRITICAL: Grant namespace creation permissions to devpod ServiceAccount or pre-create moltbook namespace"

**Status**: 🔨 **BLOCKED**

The `system:serviceaccount:devpod:default` ServiceAccount lacks cluster-scoped permissions to create namespaces.

**Attempted Action**: Applied namespace manifest but got permission denied error.

**Solution Options**:
1. **Install ArgoCD** (recommended) - ArgoCD has cluster-admin permissions
2. **Grant ClusterRole** to devpod ServiceAccount for namespace creation
3. **Pre-create namespace** manually with cluster-admin

**RBAC Created**:
- ✅ `k8s/namespace/moltbook-rbac.yml` - Role and RoleBinding for devpod in moltbook namespace
- ⚠️ Does NOT include cluster-scoped namespace creation permissions

### 2. Docker Images

**Blocker Bead**: `mo-jgo` - "Fix: Docker Hub rate limit blocking image builds"

**Related Bead**: `mo-1k0` - "Build and push Moltbook Docker images to ghcr.io"

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
