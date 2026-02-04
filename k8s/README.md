# Moltbook Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Moltbook platform to ardenone-cluster.

## Architecture

- **Namespace**: `moltbook`
- **Database**: PostgreSQL cluster (CNPG with 3 instances)
- **API Backend**: Node.js Express API (2 replicas)
- **Frontend**: Next.js web application (2 replicas)
- **Ingress**: Traefik IngressRoutes with Let's Encrypt TLS
- **GitOps**: ArgoCD for automated deployments

## Prerequisites

1. Kubernetes cluster (ardenone-cluster) with:
   - CNPG operator installed
   - Traefik ingress controller with Let's Encrypt cert resolver
   - Sealed Secrets controller
   - ArgoCD

2. Container images built and pushed to registry:
   - `ghcr.io/moltbook/api:latest`
   - `ghcr.io/moltbook/frontend:latest`

3. DNS records configured (via ExternalDNS + Cloudflare):
   - `moltbook.ardenone.com` → Traefik LoadBalancer
   - `api-moltbook.ardenone.com` → Traefik LoadBalancer

## Deployment Steps

### 1. Create Sealed Secrets

The following secrets need to be created before deploying:

#### PostgreSQL Superuser Secret

```bash
# Generate secure password
POSTGRES_SUPERUSER_PASSWORD=$(openssl rand -base64 32)

# Create secret from template
cat > /tmp/postgres-superuser-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-postgres-superuser
  namespace: moltbook
type: kubernetes.io/basic-auth
stringData:
  username: postgres
  password: "$POSTGRES_SUPERUSER_PASSWORD"
EOF

# Seal it
kubeseal --format yaml < /tmp/postgres-superuser-secret.yml > secrets/postgres-superuser-sealedsecret.yml

# Clean up temp file
rm /tmp/postgres-superuser-secret.yml
```

#### Application User Secret

```bash
# Generate secure password
APP_USER_PASSWORD=$(openssl rand -base64 32)

# Create secret from template
cat > /tmp/postgres-app-user-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-postgres-app-user
  namespace: moltbook
type: kubernetes.io/basic-auth
stringData:
  username: moltbook
  password: "$APP_USER_PASSWORD"
EOF

# Seal it
kubeseal --format yaml < /tmp/postgres-app-user-secret.yml > database/postgres-app-user-sealedsecret.yml

# Clean up
rm /tmp/postgres-app-user-secret.yml
```

#### Database Connection String

```bash
# Use the same password from above
cat > /tmp/db-connection-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-db-connection
  namespace: moltbook
type: Opaque
stringData:
  DATABASE_URL: "postgresql://moltbook:$APP_USER_PASSWORD@moltbook-postgres-rw.moltbook.svc.cluster.local:5432/moltbook?sslmode=require"
EOF

# Seal it
kubeseal --format yaml < /tmp/db-connection-secret.yml > secrets/db-connection-sealedsecret.yml

# Clean up
rm /tmp/db-connection-secret.yml
```

#### Application Secrets (JWT, etc.)

```bash
# Generate JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# Create secret from template
cat > /tmp/moltbook-secrets.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: moltbook-secrets
  namespace: moltbook
type: Opaque
stringData:
  JWT_SECRET: "$JWT_SECRET"
  REDIS_URL: ""  # Optional, leave empty if not using Redis
EOF

# Seal it
kubeseal --format yaml < /tmp/moltbook-secrets.yml > secrets/moltbook-sealedsecret.yml

# Clean up
rm /tmp/moltbook-secrets.yml
```

### 2. Create Database User

After deploying the PostgreSQL cluster, create the application user:

```bash
# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready cluster/moltbook-postgres -n moltbook --timeout=300s

# Connect to PostgreSQL and create user
kubectl exec -it -n moltbook moltbook-postgres-1 -- psql -U postgres -d moltbook -c "
CREATE USER moltbook WITH PASSWORD '$APP_USER_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE moltbook TO moltbook;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO moltbook;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO moltbook;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO moltbook;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO moltbook;
"
```

### 3. Apply Database Schema

```bash
# Apply schema from ConfigMap
kubectl exec -it -n moltbook moltbook-postgres-1 -- psql -U moltbook -d moltbook < database/schema-configmap.yml
```

### 4. Build and Push Container Images

```bash
# API
cd ../api
docker build -t ghcr.io/moltbook/api:latest .
docker push ghcr.io/moltbook/api:latest

# Frontend
cd ../moltbook-frontend
docker build -t ghcr.io/moltbook/frontend:latest .
docker push ghcr.io/moltbook/frontend:latest
```

### 5. Deploy with ArgoCD

```bash
# Apply ArgoCD Application
kubectl apply -f argocd/moltbook-application.yml

# Watch the deployment
argocd app get moltbook --watch

# Or with kubectl
kubectl get pods -n moltbook -w
```

## Manual Deployment (without ArgoCD)

If deploying manually without ArgoCD:

```bash
# Apply in order
kubectl apply -f namespace/
kubectl apply -f secrets/  # Only SealedSecrets
kubectl apply -f database/
kubectl apply -f api/
kubectl apply -f frontend/
kubectl apply -f ingress/
```

## Verification

### Check All Resources

```bash
# Check namespace
kubectl get all -n moltbook

# Check PostgreSQL cluster status
kubectl get cluster -n moltbook
kubectl cnpg status moltbook-postgres -n moltbook

# Check secrets
kubectl get sealedsecrets -n moltbook
kubectl get secrets -n moltbook

# Check pods
kubectl get pods -n moltbook -o wide

# Check services
kubectl get svc -n moltbook

# Check ingress routes
kubectl get ingressroute -n moltbook
```

### Test Endpoints

```bash
# Health check API
curl https://api-moltbook.ardenone.com/api/v1/health

# Test frontend
curl -I https://moltbook.ardenone.com
```

### Check Logs

```bash
# API logs
kubectl logs -n moltbook -l app=moltbook-api -f

# Frontend logs
kubectl logs -n moltbook -l app=moltbook-frontend -f

# Database logs
kubectl logs -n moltbook moltbook-postgres-1 -f
```

## Troubleshooting

### PostgreSQL Issues

```bash
# Check cluster status
kubectl describe cluster moltbook-postgres -n moltbook

# Check backup status
kubectl get backup -n moltbook

# Manual backup
kubectl cnpg backup moltbook-postgres -n moltbook
```

### API Connection Issues

```bash
# Test database connectivity from API pod
kubectl exec -it -n moltbook deployment/moltbook-api -- sh
# Inside pod:
# nc -zv moltbook-postgres-rw.moltbook.svc.cluster.local 5432
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n moltbook

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

## Scaling

```bash
# Scale API replicas
kubectl scale deployment moltbook-api -n moltbook --replicas=3

# Scale frontend replicas
kubectl scale deployment moltbook-frontend -n moltbook --replicas=3

# Scale PostgreSQL cluster (careful!)
kubectl patch cluster moltbook-postgres -n moltbook --type merge -p '{"spec":{"instances":5}}'
```

## Maintenance

### Database Backups

CNPG automatically handles backups if S3 credentials are configured in `database/postgres-cluster.yml`.

### Database Migrations

```bash
# Run migrations from API pod
kubectl exec -it -n moltbook deployment/moltbook-api -- npm run db:migrate
```

### Update Images

ArgoCD will auto-sync if configured. For manual updates:

```bash
# Update API image
kubectl set image deployment/moltbook-api -n moltbook api=ghcr.io/moltbook/api:v1.2.3

# Update frontend image
kubectl set image deployment/moltbook-frontend -n moltbook frontend=ghcr.io/moltbook/frontend:v1.2.3
```

## Security Notes

1. All secrets MUST be sealed before committing to Git
2. Secret templates (`*-secret-template.yml`) should NEVER be committed with real values
3. TLS certificates are automatically managed by Let's Encrypt via Traefik
4. Database uses SSL connections (`sslmode=require`)
5. All containers run as non-root users (UID 1001)

## Directory Structure

```
k8s/
├── README.md                          # This file
├── namespace/
│   └── moltbook-namespace.yml        # Namespace definition
├── database/
│   ├── postgres-cluster.yml          # CNPG cluster with 3 instances
│   ├── postgres-app-user-secret-template.yml  # Template for app user
│   └── schema-configmap.yml          # Database schema
├── secrets/
│   ├── postgres-superuser-secret-template.yml
│   ├── moltbook-secrets-template.yml
│   └── db-connection-secret-template.yml
├── api/
│   ├── deployment.yml                # API backend deployment
│   └── service.yml                   # API service
├── frontend/
│   ├── deployment.yml                # Frontend deployment
│   └── service.yml                   # Frontend service
├── ingress/
│   ├── api-ingressroute.yml          # Traefik route for API
│   └── frontend-ingressroute.yml     # Traefik route for frontend
└── argocd/
    └── moltbook-application.yml      # ArgoCD app definition
```

## URLs

- **Frontend**: https://moltbook.ardenone.com
- **API**: https://api-moltbook.ardenone.com
- **API Health**: https://api-moltbook.ardenone.com/api/v1/health
- **API Docs**: https://api-moltbook.ardenone.com/api/v1/docs (if implemented)
