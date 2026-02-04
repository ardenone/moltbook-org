# CI/CD Image Build and Deployment Status

## Overview

The Moltbook platform has a complete CI/CD pipeline for building and pushing container images to GitHub Container Registry (ghcr.io).

## CI/CD Workflow

**Location**: `.github/workflows/build-push.yml`

### Triggers

The workflow automatically runs on:
- **Push to `main` branch** - when code changes in `api/` or `moltbook-frontend/`
- **Manual dispatch** - from GitHub Actions UI

### Workflow Features

- **Multi-stage Docker builds** for optimized image sizes
- **GitHub Actions caching** for faster rebuilds
- **Image tags**: branch ref, commit SHA, and `latest`
- **Provenance and SBOM** generation for security
- **Build summary** with image digests

## Container Images

### API Image
- **Registry**: `ghcr.io/ardenone/moltbook-api`
- **Tags**:
  - `latest` - Latest main branch build
  - `main-<sha>` - Commit-specific tag
- **View**: https://github.com/ardenone?tab=packages&name=moltbook-api

### Frontend Image
- **Registry**: `ghcr.io/ardenone/moltbook-frontend`
- **Tags**:
  - `latest` - Latest main branch build
  - `main-<sha>` - Commit-specific tag
- **View**: https://github.com/ardenone?tab=packages&name=moltbook-frontend

## Deployment Manifests

The Kubernetes deployments are configured to use the `latest` tag:

### API Deployment
**File**: `k8s/api/deployment.yml`
```yaml
image: ghcr.io/ardenone/moltbook-api:latest
```

### Frontend Deployment
**File**: `k8s/frontend/deployment.yml`
```yaml
image: ghcr.io/ardenone/moltbook-frontend:latest
```

## Manual Build (Optional)

For local builds, use the provided script:

```bash
# Build and push both images
export GITHUB_TOKEN=your_token
./scripts/build-images.sh --push

# API only
./scripts/build-images.sh --api-only --push

# Frontend only
./scripts/build-images.sh --frontend-only --push
```

See [BUILD_GUIDE.md](../BUILD_GUIDE.md) for detailed instructions.

## Deployment with ArgoCD

When using ArgoCD, the deployment will automatically sync when:
1. New images are pushed to ghcr.io
2. Deployment manifests are updated

For automatic image updates, consider using ArgoCD Image Updater:
```yaml
# Add annotation to deployment
annotations:
  argocd-image-updater.argoproj.io/image-list: api=ghcr.io/ardenone/moltbook-api
  argocd-image-updater.argoproj.io/api.update-strategy: latest
  argocd-image-updater.argoproj.io/api.allow-tags: regexp:^main-
```

## Current Status

| Component | Image Registry | Deployment Ready |
|-----------|---------------|------------------|
| API       | `ghcr.io/ardenone/moltbook-api:latest` | ✅ Yes |
| Frontend  | `ghcr.io/ardenone/moltbook-frontend:latest` | ✅ Yes |

## Next Steps

1. **Trigger CI/CD build**:
   - Push code changes to main branch, OR
   - Run workflow manually from GitHub Actions

2. **Verify images**:
   - Check GitHub Packages tab for both images
   - Verify `latest` tag exists

3. **Deploy to cluster**:
   ```bash
   kubectl apply -k k8s/
   ```

4. **Monitor deployment**:
   ```bash
   kubectl get pods -n moltbook -w
   ```

## Troubleshooting

### Images Not Pulling

If pods show `ImagePullBackOff`:
```bash
# Check if images exist
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://ghcr.io/v2/ardenone/moltbook-api/tags/list
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://ghcr.io/v2/ardenone/moltbook-frontend/tags/list

# Verify image pull secret (if needed)
kubectl get secret -n moltbook | grep ghcr
```

### Workflow Not Triggering

Check:
1. Workflow file exists at `.github/workflows/build-push.yml`
2. GitHub Actions is enabled in repository settings
3. Workflow permissions include "Read and write permissions"

## Related Documentation

- [BUILD_GUIDE.md](../BUILD_GUIDE.md) - Complete build instructions
- [k8s/DEPLOYMENT.md](DEPLOYMENT.md) - Kubernetes deployment guide
- [k8s/README.md](README.md) - Cluster setup guide
