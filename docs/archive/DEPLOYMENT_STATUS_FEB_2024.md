# Moltbook Deployment Status - February 2024

**Task**: mo-saz - Implementation: Deploy Moltbook platform to ardenone-cluster
**Date**: 2026-02-04
**Status**: Implementation Complete, Deployment Blocked

## Summary

The Moltbook platform has been fully implemented with production-ready Kubernetes manifests. All manifests are validated and ready for deployment. However, two blockers prevent immediate deployment:

1. **CRITICAL**: Namespace creation requires cluster-admin permissions
2. **HIGH**: Docker image builds fail due to overlay filesystem issues in devpod

## Completed Work

### 1. Kubernetes Manifests (24 Resources)

All manifests created and validated:

| Component | Resources | File | Status |
|-----------|-----------|------|--------|
| **Namespace** | 1 Namespace, 1 Role, 1 RoleBinding | `k8s/namespace/` | Ready |
| **Database** | 1 CNPG Cluster, 1 ConfigMap, 1 Deployment, 1 Service | `k8s/database/` | Ready |
| **Redis** | 1 Deployment, 1 Service, 1 ConfigMap | `k8s/redis/` | Ready |
| **API Backend** | 1 Deployment, 1 Service, 1 ConfigMap, 1 IngressRoute | `k8s/api/` | Ready |
| **Frontend** | 1 Deployment, 1 Service, 1 ConfigMap, 1 IngressRoute | `k8s/frontend/` | Ready |
| **Secrets** | 3 SealedSecrets | `k8s/secrets/` | Encrypted |

### 2. Infrastructure Verification

All required operators are running:

```bash
# CNPG Operator
kubectl get pods -n cnpg-system
# cnpg-ardenone-cluster-cloudnative-pg-6f777c6778-d5x4p   1/1     Running

# Sealed Secrets Controller
kubectl get pods -n sealed-secrets
# sealed-secrets-ardenone-cluster-5969b964f9-vcsbl   1/1     Running

# Traefik Ingress
kubectl get pods -n traefik
# traefik-ardenone-cluster-*   1/1     Running (3 replicas)
```

### 3. Validation

```bash
cd /home/coder/Research/moltbook-org/k8s
kubectl kustomize .
# Output: 24 manifest sections generated successfully
```

## Blockers

### Blocker 1: Namespace Creation (CRITICAL - Priority 0)

**Bead**: mo-1a8

**Error**:
```
Error from server (Forbidden): namespaces is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
in API group "" at the cluster scope
```

**Resolution Options**:

Option A - Cluster Admin Creates Namespace (Fastest):
```bash
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

Option B - Grant Namespace Creation Permissions:
```bash
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

Option C - Install ArgoCD (Best Long-term):
ArgoCD has cluster-admin permissions and can create namespaces automatically via GitOps.

### Blocker 2: Docker Image Builds (HIGH - Priority 1)

**Bead**: mo-1nh

**Error**:
```
failed to solve: mount source: "overlay"... err: invalid argument
```

This is a known issue with Docker BuildKit in containerized environments (devpods).

**Resolution Options**:

Option A - GitHub Actions (Recommended):
1. Push code to GitHub repository
2. Trigger `.github/workflows/build-push.yml` workflow
3. Images automatically built and pushed to `ghcr.io/ardenone/moltbook-*`

Option B - Build on Different System:
Build images on a system with full Docker daemon access.

Option C - Use Pre-built Images:
If images exist elsewhere, update image references in `k8s/kustomization.yml`.

**Images Required**:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

## Domain Configuration

Domains configured for ExternalDNS + Traefik:

- `moltbook.ardenone.com` → Frontend (Next.js)
- `api-moltbook.ardenone.com` → API (Express.js)

## Deployment Procedure (Once Blockers Resolved)

### Step 1: Create Namespace (Cluster Admin)
```bash
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

### Step 2: Deploy All Resources
```bash
kubectl apply -k k8s/
```

### Step 3: Monitor Deployment
```bash
# Watch pods come online
kubectl get pods -n moltbook -w

# Check PostgreSQL cluster status
kubectl get cluster -n moltbook

# Verify secrets were decrypted
kubectl get secrets -n moltbook
```

### Step 4: Verify External Access
```bash
# Test frontend (after DNS propagation)
curl -I https://moltbook.ardenone.com

# Test API health endpoint
curl https://api-moltbook.ardenone.com/health
```

## Architecture

```
Internet (HTTPS)
    ↓
Cloudflare DNS
    ↓
Traefik Ingress Controller (TLS termination via Let's Encrypt)
    ↓
┌─────────────────────────────────────────────────────────┐
│ moltbook Namespace                                       │
│                                                          │
│  moltbook.ardenone.com → Frontend Service (ClusterIP)   │
│      ↓                                                   │
│  moltbook-frontend Deployment (2 replicas)              │
│                                                          │
│  api-moltbook.ardenone.com → API Service (ClusterIP)    │
│      ↓                                                   │
│  moltbook-api Deployment (2 replicas)                   │
│      ↓                                                   │
│  moltbook-db (CloudNativePG)                            │
│  redis Deployment (1 replica)                           │
└─────────────────────────────────────────────────────────┘
```

## Next Steps

1. **Resolve mo-1a8** - Get namespace created (cluster-admin action)
2. **Resolve mo-1nh** - Build Docker images (GitHub Actions or external build)
3. Deploy using `kubectl apply -k k8s/`
4. Verify services are accessible via configured domains

## Files Created

All files are in `/home/coder/Research/moltbook-org/k8s/`:
- `kustomization.yml` - Main kustomization file
- `namespace/moltbook-namespace.yml` - Namespace definition
- `namespace/moltbook-rbac.yml` - Role and RoleBinding
- `database/cluster.yml` - CNPG PostgreSQL cluster
- `database/schema-configmap.yml` - SQL schema
- `database/schema-init-deployment.yml` - Schema initialization
- `database/service.yml` - Database service
- `redis/deployment.yml` - Redis deployment
- `redis/service.yml` - Redis service
- `redis/configmap.yml` - Redis configuration
- `api/deployment.yml` - API deployment
- `api/service.yml` - API service
- `api/configmap.yml` - API environment config
- `api/ingressroute.yml` - API ingress + middlewares
- `frontend/deployment.yml` - Frontend deployment
- `frontend/service.yml` - Frontend service
- `frontend/configmap.yml` - Frontend environment config
- `frontend/ingressroute.yml` - Frontend ingress + middlewares
- `secrets/moltbook-api-sealedsecret.yml` - API secrets (encrypted)
- `secrets/moltbook-postgres-superuser-sealedsecret.yml` - DB superuser (encrypted)
- `secrets/moltbook-db-credentials-sealedsecret.yml` - DB app user (encrypted)
- `argocd-application.yml` - ArgoCD Application (for GitOps)
