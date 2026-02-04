# Moltbook Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Moltbook to ardenone-cluster using ArgoCD GitOps.

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

### 1. Deploy via ArgoCD

Apply the ArgoCD Application manifest:

```bash
kubectl apply -f argocd-application.yml
```

### 2. Manual Deployment (for testing)

```bash
# Create namespace
kubectl create namespace moltbook

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
