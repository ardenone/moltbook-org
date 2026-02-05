# Docker Image Build Process

## Problem: Overlay Filesystem Limitations in Devpod

Docker/Podman cannot build container images inside devpod/containerized environments due to overlay filesystem limitations. Linux kernel does not support nested overlay filesystems, causing build failures with errors like:

```
mount source: overlay... invalid argument
```

## Solution 1: GitHub Actions Workflow (RECOMMENDED)

The preferred method for building Docker images is using GitHub Actions, which runs on GitHub's Ubuntu runners with native Docker support.

### How It Works

- **Automatic**: Builds trigger on push to `main` branch or on pull requests
- **Cached**: Uses GitHub Actions cache for faster builds
- **Secure**: Uses GitHub's built-in authentication with `GITHUB_TOKEN`
- **Multi-platform**: Supports multiple architectures

### Usage

1. **Automatic builds**: Simply push to `main` branch
   ```bash
   git push origin main
   ```

2. **Manual trigger**: Go to Actions tab in GitHub, select "Build Container Images", click "Run workflow"

3. **Tagged releases**: Create a git tag to build with version tags
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

### Workflow Location

`.github/workflows/build-images.yml`

### Features

- Builds both API and Frontend images in parallel
- Pushes to `ghcr.io/ardenone/moltbook-api` and `ghcr.io/ardenone/moltbook-frontend`
- Tags images with branch name, commit SHA, and `latest`
- Updates Kubernetes manifests automatically after successful build
- Provides build summary with image digests

## Solution 2: Local Build (for development)

For local development, build images from your physical machine or VM (not from devpod).

### Prerequisites

- Docker or Podman installed
- GitHub Personal Access Token with `write:packages` scope

### Usage

```bash
# Set your GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Build and push images
./scripts/build-images.sh --push

# Build only API
./scripts/build-images.sh --push --api-only

# Build with custom tag
./scripts/build-images.sh --push --tag v1.0.0
```

### Script Location

`scripts/build-images.sh`

### Environment Detection

The script automatically detects if running in a containerized environment and provides helpful error messages with alternative solutions.

## Solution 3: Kaniko (Kubernetes-based)

For building images within Kubernetes clusters, use kaniko - a daemonless container image builder.

### Kaniko Configuration

`scripts/build-with-kaniko.yml`

### Usage

```bash
# Create docker registry secret
kubectl create secret docker-registry docker-config \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=YOUR_GITHUB_TOKEN \
  --namespace=moltbook

# Apply kaniko build configuration
kubectl apply -f scripts/build-with-kaniko.yml

# Scale up the builder deployment
kubectl scale deployment moltbook-kaniko-builder --replicas=1 -n moltbook

# Watch the build
kubectl logs -f deployment/moltbook-kaniko-builder -n moltbook

# Scale down when done
kubectl scale deployment moltbook-kaniko-builder --replicas=0 -n moltbook
```

**NOTE**: Per project constraints, Kubernetes Jobs are not recommended. Use the Deployment pattern instead for ArgoCD compatibility.

## Image Registry

All images are stored in GitHub Container Registry (GHCR):

- **API**: `ghcr.io/ardenone/moltbook-api:latest`
- **Frontend**: `ghcr.io/ardenone/moltbook-frontend:latest`

### Viewing Images

- [API Package](https://github.com/ardenone?tab=packages&name=moltbook-api)
- [Frontend Package](https://github.com/ardenone?tab=packages&name=moltbook-frontend)

## Kubernetes Deployment

After images are built and pushed, update your Kubernetes deployment:

```bash
# The GitHub Actions workflow automatically updates k8s/kustomization.yml
# Or manually update the image tag:

kubectl set image deployment/moltbook-api \
  api=ghcr.io/ardenone/moltbook-api:latest \
  -n moltbook

kubectl set image deployment/moltbook-frontend \
  frontend=ghcr.io/ardenone/moltbook-frontend:latest \
  -n moltbook
```

## Troubleshooting

### Build fails with overlay error

**Cause**: Running Docker/Podman inside a containerized environment

**Solution**: Use one of the recommended build methods above

### Authentication fails

**Cause**: Missing or invalid `GITHUB_TOKEN`

**Solution**: 
- Create Personal Access Token at https://github.com/settings/tokens
- Required scopes: `write:packages`, `read:packages`
- Set as environment variable: `export GITHUB_TOKEN=your_token`

### Image not found in GHCR

**Cause**: Build succeeded but push failed

**Solution**: 
- Check GitHub Actions logs
- Verify token has `write:packages` scope
- Ensure image name matches: `ghcr.io/ardenone/moltbook-*`

## Comparison of Solutions

| Solution | Ease of Use | Performance | Cost | Best For |
|----------|-------------|-------------|------|----------|
| GitHub Actions | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Free (public) | Production, CI/CD |
| Local Build | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Free | Development, testing |
| Kaniko | ⭐⭐ | ⭐⭐⭐ | Cluster resources | Kubernetes-native builds |

## Recommendations

1. **Production**: Use GitHub Actions for automated builds on push
2. **Development**: Build locally from your machine for quick iteration
3. **Emergency**: Use kaniko for cluster-based builds when other methods aren't available

## See Also

- [GitHub Actions Workflow](/.github/workflows/build-images.yml)
- [Build Script](/scripts/build-images.sh)
- [Kaniko Configuration](/scripts/build-with-kaniko.yml)
- [Dockerfiles](/api/Dockerfile, /moltbook-frontend/Dockerfile)
