# Moltbook Platform Deployment Summary - 2026-02-04

## Deployment Status: READY - BLOCKER: Namespace Creation Required

**Updated**: 2026-02-04 16:44 UTC
**Bead ID**: mo-saz
**Blocker Bead**: mo-2gg [P0] - CRITICAL: Create moltbook namespace in ardenone-cluster

### Completed Components

All Kubernetes manifests have been created and validated:

#### 1. Infrastructure Components
- ✅ **Namespace**: `k8s/namespace/moltbook-namespace.yml`
- ✅ **RBAC**: `k8s/namespace/moltbook-rbac.yml` - Devpod ServiceAccount permissions
- ✅ **ClusterRole**: `k8s/namespace/devpod-namespace-creator-rbac.yml` - For namespace creation (requires cluster-admin)

#### 2. Database (PostgreSQL CNPG)
- ✅ **Cluster**: `k8s/database/cluster.yml` - Single instance, 10Gi storage, local-path storage class
- ✅ **Service**: `k8s/database/service.yml`
- ✅ **Schema ConfigMap**: `k8s/database/schema-configmap.yml` - Complete Moltbook database schema
- ✅ **Schema Init Deployment**: `k8s/database/schema-init-deployment.yml`

#### 3. Secrets (SealedSecrets)
- ✅ **PostgreSQL Superuser**: `k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml`
- ✅ **DB Credentials**: `k8s/secrets/moltbook-db-credentials-sealedsecret.yml`
- ✅ **API Secrets**: `k8s/secrets/moltbook-api-sealedsecret.yml` - Includes JWT_SECRET and DATABASE_URL
- ✅ **Templates**: All template files provided for future secret generation

#### 4. Redis
- ✅ **Deployment**: `k8s/redis/deployment.yml` - Redis 7 Alpine
- ✅ **Service**: `k8s/redis/service.yml`
- ✅ **ConfigMap**: `k8s/redis/configmap.yml`

#### 5. API Backend
- ✅ **Deployment**: `k8s/api/deployment.yml` - 2 replicas, init container for migrations
- ✅ **Service**: `k8s/api/service.yml`
- ✅ **ConfigMap**: `k8s/api/configmap.yml`
- ✅ **IngressRoute**: `k8s/api/ingressroute.yml` - api-moltbook.ardenone.com

#### 6. Frontend (Next.js)
- ✅ **Deployment**: `k8s/frontend/deployment.yml` - 2 replicas
- ✅ **Service**: `k8s/frontend/service.yml`
- ✅ **ConfigMap**: `k8s/frontend/configmap.yml`
- ✅ **IngressRoute**: `k8s/frontend/ingressroute.yml` - moltbook.ardenone.com

#### 7. ArgoCD GitOps
- ✅ **Application**: `k8s/argocd-application.yml` - Auto-sync with CreateNamespace=true
- ✅ **Kustomization**: `k8s/kustomization.yml` - Complete resource ordering

### Traefik IngressRoute Configuration

**Frontend**: `moltbook.ardenone.com`
- HTTPS with Let's Encrypt
- Security headers middleware (CSP, X-Frame-Options, etc.)
- Connects to: `moltbook-frontend` service on port 80

**API**: `api-moltbook.ardenone.com`
- HTTPS with Let's Encrypt
- CORS middleware (allows moltbook.ardenone.com)
- Rate limiting middleware (100 req/min, burst 50)
- Connects to: `moltbook-api` service on port 80

### Deployment Blocker

**Issue**: The `moltbook` namespace does not exist, and the devpod ServiceAccount lacks cluster-scoped permission to create namespaces.

**Error**: 
```
Error from server (Forbidden): namespaces is forbidden: User "system:serviceaccount:devpod:default" 
cannot create resource "namespaces" in API group "" at the cluster scope
```

**Cluster Status**: ardenone-cluster does NOT have ArgoCD deployed. ArgoCD CRDs exist but no argocd namespace.

**Resolution Options**:

1. **Direct Namespace Creation (Fastest)**:
   - Cluster admin runs: `kubectl create namespace moltbook`
   - Then apply manifests: `kubectl apply -k k8s/`

2. **Via Cluster Admin RBAC Grant**:
   - Apply namespace creator RBAC: `kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml`
   - Then apply full kustomization: `kubectl apply -k k8s/`

3. **Via ArgoCD (NOT AVAILABLE)**:
   - ArgoCD is not deployed in ardenone-cluster (no argocd namespace exists)
   - Would require ArgoCD deployment first

### Next Steps

Once the namespace is created, deployment proceeds automatically:

1. SealedSecrets are decrypted by sealed-secrets controller
2. CNPG creates PostgreSQL cluster with replica
3. Redis deployment starts
4. API deployment runs database migrations via init container
5. Frontend deployment starts
6. Traefik IngressRoute configures external access

### Images Used

- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`
- `redis:7-alpine`

### Resource Requests

- API: 100m CPU / 128Mi RAM (request), 500m CPU / 512Mi RAM (limit)
- Frontend: 100m CPU / 128Mi RAM (request), 500m CPU / 512Mi RAM (limit)
- Redis: 50m CPU / 64Mi RAM (request), 200m CPU / 256Mi RAM (limit)
- PostgreSQL: 10Gi storage

### GitOps Workflow

The deployment follows GitOps principles:
- All manifests stored in git repository
- ArgoCD monitors the `k8s/` directory
- Changes to manifests trigger automatic sync
- SealedSecrets ensure credentials never stored in plain text

### Related Beads

- **mo-2gg**: [P0] CRITICAL: Create moltbook namespace in ardenone-cluster
- **mo-saz**: [P1] Implementation: Deploy Moltbook platform to ardenone-cluster (current bead)

### Deployment Notes

- **SealedSecret Controller**: Required for decrypting sealed secrets. Verify it's running before deployment.
- **CNPG Operator**: Already installed in cluster (cnpg-system namespace exists).
- **Traefik**: Already installed and configured with Let's Encrypt certResolver.
- **DNS Records**: Required but not yet configured (moltbook.ardenone.com, api-moltbook.ardenone.com).
