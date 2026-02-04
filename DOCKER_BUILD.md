# Docker Build Strategy for Moltbook

## Problem: Overlay Filesystem Error in Devpod

When trying to build Docker images inside the devpod, you'll encounter this error:
```
mount source: overlay... err: invalid argument
```

**Root Cause**: The devpod runs as a container inside Kubernetes (container-in-container). The host filesystem uses overlayfs, and Docker inside the container also tries to use overlayfs, causing nested overlay mounts which are not supported by the Linux kernel.

## Solution: Use GitHub Actions for Building Images

**DO NOT build Docker images inside the devpod.** Instead, use the automated GitHub Actions workflow that builds images externally, or use the helper script to trigger builds.

### Quick Start: Build via Helper Script

The easiest way to trigger builds from the devpod:

```bash
# Trigger build and watch progress
./scripts/build-images-devpod.sh --watch

# Trigger build and exit
./scripts/build-images-devpod.sh
```

This script:
- Checks your GitHub CLI authentication
- Triggers the GitHub Actions workflow
- Optionally watches the build progress in real-time
- Provides links to view the build in the browser

### Option 1: GitHub Actions (Recommended)

For production deployments, use the automated GitHub Actions workflow:

## How It Works

### 1. GitHub Actions Workflow (`.github/workflows/build-push.yml`)

The workflow automatically:
- Triggers on push to `main` branch when files in `api/`, `moltbook-frontend/`, or the workflow itself change
- Can be manually triggered via `workflow_dispatch`
- Builds both API and Frontend images using Docker Buildx
- Pushes images to GitHub Container Registry (GHCR): `ghcr.io/ardenone/moltbook-api` and `ghcr.io/ardenone/moltbook-frontend`
- Tags images with:
  - Branch name (e.g., `main`)
  - Git SHA (e.g., `main-abc1234`)
  - `latest` (for main branch)
- Automatically updates `k8s/kustomization.yml` with the new image tags
- Uses GitHub Actions cache for faster builds

### 2. Development Workflow

**For developers working on Moltbook:**

1. **Make code changes** in `api/` or `moltbook-frontend/`
2. **Commit and push** to the `main` branch:
   ```bash
   git add .
   git commit -m "feat: Add new feature"
   git push origin main
   ```
3. **GitHub Actions automatically**:
   - Builds new Docker images
   - Pushes to GHCR
   - Updates `k8s/kustomization.yml` with new image tags
4. **ArgoCD automatically**:
   - Detects the change in `k8s/kustomization.yml`
   - Pulls new images
   - Deploys to the cluster

### 3. Manual Workflow Trigger

If you need to rebuild images without pushing code changes:

```bash
# Trigger the workflow manually via GitHub CLI
gh workflow run build-push.yml

# Or via the GitHub web interface:
# https://github.com/ardenone/moltbook-org/actions/workflows/build-push.yml
```

### 4. Checking Build Status

```bash
# List recent workflow runs
gh run list --workflow=build-push.yml

# View details of a specific run
gh run view <run-id>

# Watch a running workflow
gh run watch
```

### 5. Using Specific Image Tags

The `k8s/kustomization.yml` file controls which image tags are deployed:

```yaml
images:
  - name: ghcr.io/ardenone/moltbook-api
    newName: ghcr.io/ardenone/moltbook-api
    newTag: latest  # or specific SHA like 'main-abc1234'
  - name: ghcr.io/ardenone/moltbook-frontend
    newName: ghcr.io/ardenone/moltbook-frontend
    newTag: latest  # or specific SHA like 'main-def5678'
```

To use a specific image version:
1. Find the SHA from GitHub Actions output or git log
2. Update `newTag` in `k8s/kustomization.yml`
3. Commit and push (ArgoCD will deploy)

## Comparison

| Method | Best For | Local Testing | Automation |
|--------|----------|---------------|------------|
| Devpod Buildx | Development, testing | ✅ Yes | Manual |
| GitHub Actions | Production deployments | ❌ No | ✅ Fully automatic |

## Quick Reference: Build Commands

### Local Devpod Build
```bash
# Setup (one-time)
./scripts/setup-docker-buildx.sh

# Build API only (no push)
./scripts/build-images-devpod.sh --dry-run --api-only

# Build and push API
GITHUB_TOKEN=ghp_xxx ./scripts/build-images-devpod.sh --push --api-only

# Build both and push
GITHUB_TOKEN=ghp_xxx ./scripts/build-images-devpod.sh --push

# Build with custom tag
./scripts/build-images-devpod.sh --dry-run --tag v1.0.0
```

### GitHub Actions
```bash
# Trigger manually
gh workflow run build-push.yml

# Watch the build
gh run watch

# Check status
gh run list --workflow=build-push.yml
```
- ✅ Consistent build environment
- ✅ Automated image tagging
- ✅ Build caching for speed
- ✅ Automatic deployment via ArgoCD
- ✅ SBOM and provenance for security
- ✅ No local resource usage

## Troubleshooting

### Images Not Pulling in Kubernetes

Check if the images exist in GHCR:
```bash
# List API images
gh api /user/packages/container/moltbook-api/versions

# List Frontend images
gh api /user/packages/container/moltbook-frontend/versions
```

Ensure the cluster has pull permissions:
```bash
# Check imagePullSecrets in the namespace
kubectl get secrets -n moltbook | grep docker
```

### Build Failing in GitHub Actions

Check the workflow logs:
```bash
gh run list --workflow=build-push.yml --limit 1
gh run view <run-id> --log
```

Common issues:
- Missing `GITHUB_TOKEN` permission (should be automatic)
- Dockerfile errors (test locally with `docker build`)
- Package visibility (ensure GHCR packages are public or cluster has access)

## References

- GitHub Actions Workflow: `.github/workflows/build-push.yml`
- API Dockerfile: `api/Dockerfile`
- Frontend Dockerfile: `moltbook-frontend/Dockerfile`
- Kubernetes Manifests: `k8s/`
- GHCR Packages: https://github.com/ardenone?tab=packages
