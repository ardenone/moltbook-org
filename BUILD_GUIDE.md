# Moltbook Container Image Build Guide

This guide explains how to build and push container images for the Moltbook platform deployment.

## Overview

The Moltbook platform requires two container images:
- `ghcr.io/ardenone/moltbook-api:latest` - Express.js API backend
- `ghcr.io/ardenone/moltbook-frontend:latest` - Next.js 14 frontend

## Prerequisites

### 1. GitHub Container Registry Access

To push images to `ghcr.io`, you need:

1. **GitHub Account** - Sign up at https://github.com if you don't have one
2. **Personal Access Token (PAT)** with package write permissions:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Set the following scopes:
     - `write:packages` - Required for pushing images
     - `read:packages` - Required for pulling images
   - Copy the generated token

### 2. Container Runtime

One of the following must be installed:
- **Podman** (recommended): https://podman.io/getting-started/installation
- **Docker**: https://docs.docker.com/engine/install/

### 3. Clone the Repository

```bash
git clone <repository-url> moltbook-org
cd moltbook-org
```

## Authentication Methods

### Method 1: Local Environment File (Recommended for Devpods)

Create a `.env.local` file in the project root:

```bash
# Create from template
cp .env.local.template .env.local

# Edit with your token
nano .env.local
```

Edit `.env.local`:
```bash
GITHUB_TOKEN=ghp_your_token_here
GITHUB_USERNAME=ardenone
```

Then source the environment before building:
```bash
source scripts/load-env.sh
./scripts/build-images.sh --push
```

### Method 2: Environment Variable

Set the `GITHUB_TOKEN` environment variable before running the build script:

```bash
export GITHUB_TOKEN=ghp_your_token_here
./scripts/build-images.sh --push
```

### Method 3: Podman/Docker Login

Login to the registry directly:

```bash
# Using Podman
echo "ghp_your_token_here" | podman login ghcr.io --username YOUR_GITHUB_USERNAME --password-stdin

# Using Docker
echo "ghp_your_token_here" | docker login ghcr.io --username YOUR_GITHUB_USERNAME --password-stdin
```

Then run the build script without setting `GITHUB_TOKEN` (credentials are cached).

## Building Images

### Quick Start (Build and Push)

```bash
# Set your token
export GITHUB_TOKEN=ghp_your_token_here

# Build and push both images
./scripts/build-images.sh --push
```

### Build Without Pushing (Dry Run)

```bash
./scripts/build-images.sh --dry-run
```

### Build Only One Component

```bash
# API only
./scripts/build-images.sh --api-only --push

# Frontend only
./scripts/build-images.sh --frontend-only --push
```

### Build with Specific Tag

```bash
./scripts/build-images.sh --push --tag v1.0.0
```

## Build Script Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Build images without pushing to registry |
| `--push` | Push images to registry (requires authentication) |
| `--api-only` | Build only the API image |
| `--frontend-only` | Build only the Frontend image |
| `--tag TAG` | Use specific tag instead of 'latest' |
| `--help` | Show help message |

## Manual Build (Without Script)

If you prefer to build manually without the script:

### API Image

```bash
cd api
podman build -t ghcr.io/ardenone/moltbook-api:latest .
podman push ghcr.io/ardenone/moltbook-api:latest
```

### Frontend Image

```bash
cd moltbook-frontend
podman build -t ghcr.io/ardenone/moltbook-frontend:latest .
podman push ghcr.io/ardenone/moltbook-frontend:latest
```

## GitHub Actions (CI/CD)

The repository includes a GitHub Actions workflow at `.github/workflows/build-push.yml`.

### Setting Up GitHub Actions

1. **Push the repository to GitHub**:
   ```bash
   git remote add origin https://github.com/YOUR_ORG/moltbook-org.git
   git push -u origin main
   ```

2. **Enable GitHub Actions**:
   - Go to your repository on GitHub
   - Navigate to Settings → Actions → General
   - Enable "Allow all actions and reusable workflows"

3. **Configure permissions**:
   - Go to Settings → Actions → General
   - Under "Workflow permissions", select "Read and write permissions"
   - Enable "Allow GitHub Actions to create and approve pull requests"

4. **Automatic builds**:
   - On push to `main` branch, images are automatically built and pushed
   - Changes in `api/` trigger API image rebuild
   - Changes in `moltbook-frontend/` trigger Frontend image rebuild

### Manual GitHub Actions Trigger

You can manually trigger the workflow from GitHub:
1. Go to Actions tab in your repository
2. Select "Build and Push Docker Images"
3. Click "Run workflow"
4. Select branch and click "Run workflow"

## Troubleshooting

### Authentication Failed

```
Error: unauthorized: authentication required
```

**Solution**: Verify your GitHub token has `write:packages` scope and is correctly set:
```bash
echo $GITHUB_TOKEN  # Should show your token
```

### Permission Denied

```
Error: denied: permission_denied
```

**Solution**: Ensure you're pushing to the correct organization:
- If you don't own the `moltbook` organization, use your own username instead
- Update the `ORGANIZATION` variable in the build script

### Build Context Errors

```
Error: error building image: unable to load ...
```

**Solution**: Ensure you're in the project root directory:
```bash
cd /path/to/moltbook-org
./scripts/build-images.sh
```

### Network Issues

```
Error: error fetching image ...
```

**Solution**: Check your network connection and registry accessibility:
```bash
ping ghcr.io
podman pull alpine:latest  # Test basic pull
```

## Image Registry Information

### Registry Details

- **Registry**: `ghcr.io` (GitHub Container Registry)
- **Organization**: `ardenone`
- **API Image**: `ghcr.io/ardenone/moltbook-api`
- **Frontend Image**: `ghcr.io/ardenone/moltbook-frontend`

### Using a Different Registry

If you need to use a different registry (e.g., Docker Hub, private registry):

1. Update the build script variables:
   ```bash
   REGISTRY="your-registry.example.com"
   ORGANIZATION="your-org"
   ```

2. Update Kubernetes deployment manifests:
   ```bash
   # In k8s/api/deployment.yml and k8s/frontend/deployment.yml
   image: your-registry.example.com/your-org/api:latest
   image: your-registry.example.com/your-org/frontend:latest
   ```

3. Update the Kustomization:
   ```yaml
   # In k8s/kustomization.yml
   images:
     - name: your-registry.example.com/your-org/api
       newName: your-registry.example.com/your-org/api
       newTag: latest
   ```

## Verification

After building and pushing, verify the images are available:

### Check via Podman/Docker

```bash
# Pull to verify
podman pull ghcr.io/ardenone/moltbook-api:latest
podman pull ghcr.io/ardenone/moltbook-frontend:latest

# List images
podman images | grep moltbook
```

### Check via GitHub Web UI

1. Go to https://github.com/orgs/ardenone/packages (or your GitHub username)
2. View the `moltbook-api` and `moltbook-frontend` packages
3. Verify the latest tag exists

### Test Locally

```bash
# Test API
podman run --rm -p 3000:3000 ghcr.io/ardenone/moltbook-api:latest

# Test Frontend
podman run --rm -p 3000:3000 ghcr.io/ardenone/moltbook-frontend:latest
```

## Deployment

### BLOCKER: Cluster-Admin Required for Namespace Creation

**The devpod ServiceAccount lacks cluster-admin permissions to create namespaces.**

**Current Status**: The moltbook namespace does not exist in ardenone-cluster. Creating it requires cluster-admin privileges that the devpod ServiceAccount does not have.

**Resolution Options** (requires cluster-admin):

1. **Option 1: Create moltbook namespace directly**
   ```bash
   # Run as cluster-admin
   kubectl create namespace moltbook
   ```

2. **Option 2: Apply RBAC to grant namespace creation permissions to devpod**
   ```bash
   # Run as cluster-admin - apply the RBAC manifest
   kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml

   # Then the devpod can create namespaces:
   kubectl apply -f k8s/namespace/moltbook-namespace.yml
   ```

**RBAC Manifest Location**: `k8s/namespace/devpod-namespace-creator-rbac.yml`

This manifest creates:
- `ClusterRole: namespace-creator` - Grants permission to create namespaces, roles, and rolebindings
- `ClusterRoleBinding: devpod-namespace-creator` - Binds the ClusterRole to the devpod ServiceAccount

### Deployment Steps (After Namespace Creation)

Once the namespace exists (via cluster-admin action):

```bash
# Deploy all resources
kubectl apply -k k8s/

# Monitor deployment
kubectl get pods -n moltbook -w
```

## Security Notes

1. **Never commit** your GitHub token to the repository
2. **Use environment variables** for sensitive credentials (`.env.local` is in `.gitignore`)
3. **Rotate tokens regularly** - GitHub PATs can be revoked and regenerated
4. **Use SealedSecrets** for production secrets (already implemented in this project)

## Related Documentation

- [GITHUB_TOKEN Setup Guide](docs/GITHUB_TOKEN_SETUP.md) - Detailed token configuration
- [Kubernetes Deployment Guide](k8s/README.md)
- [Deployment Status](DEPLOYMENT_READY.md)
- [k8s/CICD_DEPLOYMENT.md](k8s/CICD_DEPLOYMENT.md) - CI/CD deployment guide

## Kubernetes Manifests Validation

The Moltbook Kubernetes manifests have been created and validated in the cluster-configuration repository:

**Location**: `/home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook/`

**Structure**:
```
moltbook/
├── api/
│   ├── deployment.yml         (2 replicas, health checks, resource limits)
│   ├── service.yml            (ClusterIP, port 80)
│   ├── configmap.yml          (PORT, NODE_ENV, BASE_URL, REDIS_URL, CORS_ORIGINS)
│   └── ingressroute.yml       (api-moltbook.ardenone.com with CORS and rate limiting)
├── frontend/
│   ├── deployment.yml         (2 replicas, health checks, resource limits)
│   ├── service.yml            (ClusterIP, port 80)
│   ├── configmap.yml          (NEXT_PUBLIC_API_URL)
│   └── ingressroute.yml       (moltbook.ardenone.com with security headers)
├── database/
│   ├── cluster.yml            (CloudNativePG cluster, 1 instance, 10Gi storage)
│   ├── service.yml            (ClusterIP for postgres)
│   ├── schema-configmap.yml   (Database schema SQL)
│   └── schema-init-deployment.yml (Idempotent schema initialization - NOT a Job)
├── redis/
│   ├── deployment.yml         (1 replica, persistence disabled, maxmemory-policy allkeys-lru)
│   ├── service.yml            (ClusterIP, port 6379)
│   └── configmap.yml          (Redis configuration)
├── secrets/
│   ├── moltbook-api-sealedsecret.yml             (Encrypted API secrets)
│   ├── moltbook-api-secrets-template.yml         (Template for API secrets)
│   ├── moltbook-postgres-superuser-sealedsecret.yml (Encrypted superuser password)
│   ├── postgres-superuser-secret-template.yml    (Template for superuser)
│   ├── moltbook-db-credentials-sealedsecret.yml  (Encrypted app user credentials)
│   ├── moltbook-db-credentials-template.yml      (Template for app user)
│   └── create-sealedsecrets.sh                   (Helper script)
├── namespace/
│   ├── moltbook-namespace.yml                     (Namespace with labels)
│   ├── moltbook-rbac.yml                          (Role and RoleBinding for devpod SA)
│   └── devpod-namespace-creator-rbac.yml          (ClusterRole for namespace creation)
├── kustomization.yml          (Main kustomization with 1050 lines of output)
├── argocd-application.yml     (ArgoCD Application manifest)
└── README.md                  (Deployment documentation)
```

**Standards Compliance**:
- ✅ No `Job` or `CronJob` resources (uses idempotent Deployments)
- ✅ Domain naming follows Cloudflare convention (no nested subdomains)
  - `moltbook.ardenone.com` (frontend)
  - `api-moltbook.ardenone.com` (API)
- ✅ All secrets use SealedSecrets with `.template` files
- ✅ Health checks configured for all deployments
- ✅ Resource limits and requests defined
- ✅ Kustomization builds successfully (1050 lines)

**Image References**:
- API: `ghcr.io/ardenone/moltbook-api:latest`
- Frontend: `ghcr.io/ardenone/moltbook-frontend:latest`

**Validation**:
```bash
cd /home/coder/ardenone-cluster/cluster-configuration/ardenone-cluster/moltbook
kubectl kustomize . | wc -l
# Output: 1050 lines (manifests validated successfully)
```

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs in the Actions tab
3. Check Kubernetes pod logs: `kubectl logs -n moltbook deployment/moltbook-api`
