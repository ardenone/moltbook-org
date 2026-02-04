# Moltbook Deployment Status

**Last Updated**: 2026-02-04
**Bead**: mo-saz
**Status**: ✅ Manifests Ready, 🔨 Awaiting RBAC & Docker Images

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

## 🔨 Remaining Work

### 1. RBAC Permissions

**Follow-up Bead**: `mo-2qa` - "Setup RBAC for moltbook namespace deployment"

The devpod ServiceAccount needs permissions to deploy resources to the moltbook namespace. Options:

1. **Create Role/RoleBinding** for devpod ServiceAccount in moltbook namespace
2. **Install ArgoCD** for GitOps-based deployment (recommended)
3. **Use cluster-admin** ServiceAccount (not recommended for production)

Once RBAC is configured, deployment can proceed with:
```bash
kubectl apply -k k8s/
```

### 2. Docker Images

**Follow-up Bead**: `mo-1k0` - "Build and push Moltbook Docker images to ghcr.io"

The manifests reference these images:
- `ghcr.io/moltbook/api:latest`
- `ghcr.io/moltbook/frontend:latest`

**Options**:
1. **GitHub Actions** (Recommended): Create `.github/workflows/build-images.yml` in the moltbook-org repository
2. **Manual Build**: Use podman/docker to build and push from api/ and moltbook-frontend/ directories
3. **CI/CD Integration**: Integrate with existing CI/CD pipeline

Both subdirectories have production-ready Dockerfiles with multi-stage builds.

### 3. Deployment to Cluster

After RBAC is configured and images are built/pushed:

1. **Apply ArgoCD Application**:
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

## Next Steps

1. **Immediate**: Complete bead `mo-1k0` - Build and push Docker images
2. **Deploy**: Apply ArgoCD application to cluster
3. **Verify**: Test all services and external access
4. **Production**: Replace development secrets with proper secret management
5. **Monitor**: Set up monitoring and alerting for the platform

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
✅ Git repository clean and committed
🔨 Docker images (next step)
⏳ Deployment verification
⏳ Production secrets configuration
