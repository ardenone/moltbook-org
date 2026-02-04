# Moltbook Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Moltbook to ardenone-cluster using ArgoCD GitOps.

## Deployment Status

🚫 **BLOCKED** - Namespace creation requires cluster-admin action.

- **Current Blocker:** Namespace `moltbook` does not exist in ardenone-cluster
- **Blocker Bead:** mo-s45e (Blocker: RBAC permissions for Moltbook namespace creation)
- **Required Action:** Cluster admin must run `./setup-namespace.sh` or `kubectl create namespace moltbook`
- **Last Updated:** 2026-02-04

See `NAMESPACE_SETUP_README.md` for detailed instructions on resolving the blocker.

## Architecture

```
moltbook.ardenone.com (Frontend - Next.js)
    ↓ Traefik IngressRoute
moltbook-frontend Service (ClusterIP)
    ↓
moltbook-frontend Deployment (2 replicas)

api-moltbook.ardenone.com (API - Express.js)
    ↓ Traefik IngressRoute
moltbook-api Service (ClusterIP)
    ↓
moltbook-api Deployment (2 replicas)
    ↓
moltbook-postgres (CloudNativePG - PostgreSQL 16)
    ↓
moltbook-postgres-rw Service (ClusterIP)

redis Service (ClusterIP)
    ↓
redis Deployment (1 replica)
```

## Prerequisites

1. **CloudNativePG Operator** must be installed on the cluster
2. **Traefik** with Let's Encrypt certResolver configured
3. **ArgoCD** for GitOps deployment
4. **Manifests deployed** to `ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`

## GitOps Workflow

All Kubernetes manifests for Moltbook are stored in the `ardenone-cluster` repository under:
```
cluster-configuration/ardenone-cluster/moltbook/
```

To make changes to the deployment:
1. Modify manifests in the ardenone-cluster repository
2. Commit and push changes to GitHub
3. ArgoCD will automatically sync and apply the changes to the cluster

## Secrets

Before deploying, you need to create the following secrets:

### 1. Database Credentials

Generate strong passwords and create SealedSecrets:

```bash
# Generate secrets
cd k8s

# 1. Create database secret
kubectl create secret generic moltbook-db-credentials \
  --from-literal=password=$(openssl rand -base64 32) \
  --from-literal=jwt-secret=$(openssl rand -base64 64) \
  --from-literal=api-superuser-key=$(openssl rand -hex 32) \
  --namespace=moltbook \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > database/db-credentials-sealedsecret.yml

# 2. Create API secret with DATABASE_URL
DB_PASSWORD=$(your_generated_password)
kubectl create secret generic moltbook-api-secrets \
  --from-literal=DATABASE_URL="postgresql://moltbook:${DB_PASSWORD}@moltbook-postgres-rw.moltbook.svc.cluster.local:5432/moltbook" \
  --from-literal=JWT_SECRET=$(openssl rand -base64 64) \
  --namespace=moltbook \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > api/sealedsecret.yml
```

## Deployment Steps

### Prerequisite: Create Namespace (Requires Cluster Admin)

The moltbook namespace must be created before ArgoCD can sync resources.

**Option 1: Run the helper script (requires cluster-admin)**
```bash
./scripts/create-moltbook-namespace.sh
```

**Option 2: Manual namespace creation (requires cluster-admin)**
```bash
kubectl create namespace moltbook
```

**Option 3: Grant devpod namespace creation permissions (one-time setup)**
```bash
# Apply RBAC to allow devpod ServiceAccount to create namespaces
kubectl apply -f namespace/devpod-namespace-creator-rbac.yml

# Now namespace creation can be done from devpod
kubectl create namespace moltbook
```

### 1. Deploy via ArgoCD

Apply the ArgoCD Application manifest:

```bash
kubectl apply -f argocd-application.yml
```

Note: ArgoCD has `CreateNamespace=true` but requires cluster-admin permissions to create namespaces. The namespace must exist before ArgoCD can sync resources to it.

### 2. Manual Deployment (for testing)

```bash
# Apply secrets first
kubectl apply -f database/db-credentials-sealedsecret.yml
kubectl apply -f api/sealedsecret.yml

# Apply all resources
kubectl apply -k .
```

## DNS Configuration

The following domains should automatically be configured via ExternalDNS:

- `moltbook.ardenone.com` - Frontend
- `api-moltbook.ardenone.com` - API

## Scaling

### API Scaling
```bash
kubectl scale deployment moltbook-api -n moltbook --replicas=3
```

### Frontend Scaling
```bash
kubectl scale deployment moltbook-frontend -n moltbook --replicas=3
```

### Database Scaling
Edit `database/cluster.yml` and change `spec.instances` (requires CNPG operator support).

## Monitoring

Check pod status:
```bash
kubectl get pods -n moltbook
```

View logs:
```bash
# API logs
kubectl logs -f deployment/moltbook-api -n moltbook

# Frontend logs
kubectl logs -f deployment/moltbook-frontend -n moltbook

# Database logs
kubectl logs -f -l cnpg.io/cluster=moltbook-postgres -n moltbook
```

## Health Checks

- API Health: `https://api-moltbook.ardenone.com/health`
- Frontend: `https://moltbook.ardenone.com`

## Troubleshooting

### Database Connection Issues

Check if the database is running:
```bash
kubectl get cluster -n moltbook
kubectl describe cluster moltbook-postgres -n moltbook
```

### API Returns 502

Check API pod logs and ensure DATABASE_URL is correctly formatted:
```bash
kubectl logs -f deployment/moltbook-api -n moltbook
```

### Frontend Cannot Reach API

1. Check NEXT_PUBLIC_API_URL in frontend ConfigMap
2. Verify CORS settings in API ConfigMap
3. Check IngressRoute status

## Backups

The CNPG cluster is configured with 30-day retention. Backups are stored in the configured object storage (if configured).

To manually backup:
```bash
kubectl create job --from=cronjob/moltbook-db-backup manual-backup -n moltbook
```
