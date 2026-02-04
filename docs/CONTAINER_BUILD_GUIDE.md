# Container Build Guide for Moltbook

## Overview

Moltbook uses GitHub Actions to build and push container images to GitHub Container Registry (GHCR). The deployment manifests reference these images.

## Images

| Component | Image URL | Dockerfile |
|-----------|-----------|------------|
| API | `ghcr.io/ardenone/moltbook-api:latest` | `api/Dockerfile` |
| Frontend | `ghcr.io/ardenone/moltbook-frontend:latest` | `moltbook-frontend/Dockerfile` |

## Building Images

### Option 1: GitHub Actions (Recommended)

The `.github/workflows/build-push.yml` workflow automatically builds and pushes images when:
- Code is pushed to the `main` branch
- Changes are made to `api/**`, `moltbook-frontend/**`, or the workflow itself
- Manual trigger via `workflow_dispatch`

**To trigger a build:**

```bash
# Push to main (automatic trigger)
git push origin main

# Or trigger manually via GitHub Actions UI
# Visit: https://github.com/ardenone/moltbook-org/actions/workflows/build-push.yml
```

### Option 2: Local Build (Requires Fix)

Currently, local Docker builds in devpods fail with overlay filesystem errors:

```
ERROR: mount source: "overlay", target: "...", err: invalid argument
```

This is a known limitation in containerized development environments (devpods).

**Workaround:** Use GitHub Actions for building images.

**For local development**, you may need to:
1. Build on a non-containerized host
2. Use a VM with proper overlay filesystem support
3. Fix the devpod Docker-in-Docker configuration

### Manual Build (On Supported Host)

If you have a working Docker environment:

```bash
# Build and push API image
docker buildx build --platform linux/amd64 \
  -t ghcr.io/ardenone/moltbook-api:latest \
  --push ./api

# Build and push Frontend image
docker buildx build --platform linux/amd64 \
  -t ghcr.io/ardenone/moltbook-frontend:latest \
  --push ./moltbook-frontend
```

## Deployment

The Kubernetes deployments in `k8s/` reference the images:

```yaml
# k8s/api/deployment.yml
image: ghcr.io/ardenone/moltbook-api:latest

# k8s/frontend/deployment.yml
image: ghcr.io/ardenone/moltbook-frontend:latest
```

After images are built and pushed, ArgoCD will automatically sync the deployments.

## Image Tags

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit SHA tag

For production, consider using semantic version tags (e.g., `v1.0.0`).

## Authentication

The workflow uses GitHub's built-in `GITHUB_TOKEN` for authentication to GHCR. No additional secrets required for public repositories.

## Troubleshooting

### Images Not Pulling

1. Check if images exist on GHCR:
   - https://github.com/ardenone?tab=packages&name=moltbook-api
   - https://github.com/ardenone?tab=packages&name=moltbook-frontend

2. Verify image tags match deployment manifests

3. Check GitHub Actions workflow runs for build failures

### Local Build Fails

If you see overlay filesystem errors, use GitHub Actions instead. This is a devpod environment limitation.

## See Also

- [GitHub Actions Workflow](../.github/workflows/build-push.yml)
- [API Dockerfile](../api/Dockerfile)
- [Frontend Dockerfile](../moltbook-frontend/Dockerfile)
