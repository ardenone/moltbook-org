# Frontend Build Workaround - Devpod Storage Issue

## Problem Description

The frontend container image build is blocked by two issues:

1. **Next.js 16.1.6 Compatibility**: Requires Node.js 20.9.0+
2. **Devpod Overlay Filesystem Corruption**: Docker builds fail in devpod environments due to nested overlayfs

### Error Symptoms

When attempting to build the frontend image in a devpod:
- Docker build fails with overlay filesystem errors
- Build hangs or times out during layer operations
- Inode exhaustion or storage-related errors

## Root Cause

Devpods run as containers within the ardenone-cluster. When attempting to run Docker builds inside a devpod, this creates **nested overlay filesystems**:
- Devpod storage layer (outer overlayfs)
- Docker build layer storage (inner overlayfs)

This nested overlayfs configuration causes filesystem corruption and build failures.

## Solution: External CI/CD Build

The recommended solution is to use **GitHub Actions** for building container images, which has been pre-configured in `.github/workflows/build-images.yml`.

### Build Infrastructure

| Component | Location | Purpose |
|-----------|----------|---------|
| GitHub Actions | `.github/workflows/build-images.yml` | CI/CD pipeline for image builds |
| Frontend Dockerfile | `moltbook-frontend/Dockerfile` | Multi-stage build with node:20-alpine |
| GHCR Registry | `ghcr.io/ardenone/moltbook-frontend` | Container image registry |

### Automated Build Triggers

The GitHub Actions workflow automatically triggers on:
- Push to `main` branch (changes to `api/`, `moltbook-frontend/`, or workflow files)
- New tags (e.g., `v1.0.0`)
- Pull requests (build only, no push)
- Manual dispatch via GitHub UI

## Manual Build Instructions

### Option 1: Trigger GitHub Actions (Recommended)

Push a commit to trigger the automated build:

```bash
# Method A: Empty commit to trigger build
git commit --allow-empty -m "chore: Trigger frontend build"
git push origin main

# Method B: Update workflow dispatch (if enabled)
gh workflow run build-images.yml
```

### Option 2: Manual Build with GitHub CLI

```bash
# Authenticate with GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build locally using buildx (avoids overlayfs issues)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/ardenone/moltbook-frontend:latest \
  --push \
  ./moltbook-frontend
```

### Option 3: Manual Build with Docker (Not Recommended in Devpod)

```bash
cd moltbook-frontend
docker build -t moltbook-frontend:local .
```

**Note**: This will likely fail in devpod due to overlayfs issues.

## Deployment After Build

Once the image is built and pushed to GHCR:

1. **Verify image exists**:
   ```bash
   docker pull ghcr.io/ardenone/moltbook-frontend:latest
   ```

2. **Update deployment** (if needed):
   ```bash
   kubectl set image deployment/moltbook-frontend \
    frontend=ghcr.io/ardenone/moltbook-frontend:latest \
    -n moltbook
   ```

3. **Verify deployment**:
   ```bash
   kubectl get pods -n moltbook -l app=moltbook-frontend
   ```

## Deployment Manifest

The frontend deployment uses:
- **Image**: `ghcr.io/ardenone/moltbook-frontend:latest`
- **Replicas**: 2
- **Resources**: 100m-500m CPU, 128Mi-512Mi RAM
- **Health checks**: HTTP / path checks

## Kaniko Alternative (Cluster-Based Build)

The cluster has a Kaniko build runner deployment at `k8s/kaniko/build-runner-deployment.yml`.

**Limitation**: The current Kaniko configuration requires source files to be manually copied to the build context (`/workspace`), which makes it less convenient than GitHub Actions.

To use Kaniko:
```bash
# 1. Copy source files to the pod
kubectl cp moltbook-frontend/ deployment/kaniko-build-runner:/workspace/moltbook-frontend

# 2. Trigger build
kubectl exec -it deployment/kaniko-build-runner -- /scripts/build-frontend.sh
```

## Next.js 16 Requirements

The frontend application uses:
- **Next.js**: 16.1.6
- **React**: 19.0.0
- **Node.js**: >=20.9.0

The Dockerfile uses `node:20-alpine` which satisfies these requirements.

## Recovery from Devpod Storage Issue

Once the devpod storage layer is fixed, local Docker builds should work again. Monitor for:
- Normal Docker build operations completing successfully
- No overlayfs-related errors in Docker logs
- Stable inode counts in `/tmp` and build directories

## Related Files

- `.github/workflows/build-images.yml` - GitHub Actions CI/CD pipeline
- `moltbook-frontend/Dockerfile` - Container image definition
- `moltbook-frontend/package.json` - Dependencies and build scripts
- `k8s/frontend/deployment.yml` - Kubernetes deployment manifest
- `k8s/kaniko/build-runner-deployment.yml` - Kaniko build runner

## Status

- [x] Next.js 16 compatibility verified (Node.js 20+)
- [x] GitHub Actions workflow configured
- [x] Build infrastructure documented
- [ ] Frontend image built and pushed to GHCR
- [ ] Deployment verified

## Related Beads

- mo-1xqe - This bead: Fix frontend build issue
- Future: Fix devpod storage layer for local builds
