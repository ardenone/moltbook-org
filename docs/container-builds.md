# Container Image Builds

This document describes how to build and push container images for Moltbook.

## Images

- **API**: `ghcr.io/ardenone/moltbook-api:latest`
- **Frontend**: `ghcr.io/ardenone/moltbook-frontend:latest`

## Automated Builds (Recommended)

Container images are automatically built and pushed via GitHub Actions when changes are pushed to the `main` branch.

### Trigger Automatic Build

```bash
# Commit and push changes to trigger build
git add .
git commit -m "feat: Update API/Frontend"
git push origin main
```

The workflow will:
1. Build both images with Docker Buildx
2. Tag images with branch name, commit SHA, and `latest`
3. Push to GitHub Container Registry (ghcr.io)
4. Use GitHub Actions cache for faster builds

### Manual Workflow Trigger

```bash
# Trigger via GitHub CLI
gh workflow run build-images.yml

# Or via GitHub UI
# Go to Actions → Build and Push Container Images → Run workflow
```

## Local Builds

### Prerequisites

- Docker or Podman with build access
- GitHub Personal Access Token with `write:packages` scope
- Not running in a containerized environment (no Docker-in-Docker on overlay fs)

### Build Script

```bash
# Set GitHub token
export GITHUB_TOKEN=your_token_here

# Build and push both images
./scripts/build-images.sh --push

# Build specific image only
./scripts/build-images.sh --push --api-only
./scripts/build-images.sh --push --frontend-only

# Build with custom tag
./scripts/build-images.sh --push --tag v1.0.0

# Dry run (build without pushing)
./scripts/build-images.sh --dry-run
```

### Manual Docker Build

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build API image
docker build -t ghcr.io/ardenone/moltbook-api:latest ./api
docker push ghcr.io/ardenone/moltbook-api:latest

# Build Frontend image
docker build -t ghcr.io/ardenone/moltbook-frontend:latest ./moltbook-frontend
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

## Known Limitations

### Devpod Environment

**The devpod environment cannot build images** due to overlay filesystem limitations when running Docker-in-Docker:

```
Error: mount source: "overlay"... invalid argument
```

This is a fundamental limitation of nested overlay filesystems. Use one of these alternatives:

1. **GitHub Actions** (recommended) - Automatic builds on push
2. **Local machine** - Build from non-containerized environment
3. **kaniko** - Daemonless builder for Kubernetes
4. **BuildKit DaemonSet** - Dedicated build infrastructure

## Kubernetes Integration

Images are referenced in Kubernetes manifests:

- `deployment/api/deployment.yml` - API deployment
- `deployment/frontend/deployment.yml` - Frontend deployment

After images are pushed, update ArgoCD to sync:

```bash
# Auto-sync is enabled, or manually sync
argocd app sync moltbook
```

## Troubleshooting

### Authentication Fails

```bash
# Verify GitHub token has correct scopes
gh auth status

# Refresh token
gh auth refresh -s write:packages

# Extract token
export GITHUB_TOKEN=$(gh auth token)
```

### Build Fails in Devpod

Use GitHub Actions instead. The devpod environment does not support Docker builds due to filesystem constraints.

### Image Not Found in Cluster

```bash
# Verify image exists in GHCR
gh api /user/packages/container/moltbook-api/versions
gh api /user/packages/container/moltbook-frontend/versions

# Check deployment image pull status
kubectl describe pod -n moltbook -l app=moltbook-api
```

### Pull Image Locally

```bash
# Login and pull
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/ardenone/moltbook-api:latest
docker pull ghcr.io/ardenone/moltbook-frontend:latest
```

## References

- Build script: `scripts/build-images.sh`
- API Dockerfile: `api/Dockerfile`
- Frontend Dockerfile: `moltbook-frontend/Dockerfile`
- GitHub Actions workflow: `.github/workflows/build-images.yml`
