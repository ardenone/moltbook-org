# Moltbook Container Build Instructions

## Overview

Moltbook requires two container images to be built and pushed to GitHub Container Registry (GHCR):
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

## Devpod Build Limitation

**IMPORTANT**: Container builds cannot be performed inside devpods due to overlay filesystem restrictions. The build must be executed on a machine with full Docker/Podman access.

### Error when building in devpod:
```
failed to mount: mount source: "overlay", target: "/var/...", fstype: overlay, flags: 0,
data: "...", err: invalid argument
```

## Build Location Options

### Option 1: Local Machine (Recommended)
Build on your local development machine with Docker Desktop/Podman installed.

### Option 2: CI/CD Pipeline
Use GitHub Actions to build and push images automatically.

### Option 3: Dedicated Build Server
Use a server/container with proper Docker-in-Docker (DinD) support.

## Prerequisites

1. **Docker or Podman** installed and running
2. **GitHub Personal Access Token** with `write:packages` and `read:packages` scopes
   - Create at: https://github.com/settings/tokens
3. **Git clone** of the moltbook-org repository

## Build Instructions

### Step 1: Clone and Navigate

```bash
git clone https://github.com/ardenone/moltbook-org.git
cd moltbook-org
```

### Step 2: Set GitHub Token

```bash
export GITHUB_TOKEN=your_token_here
```

### Step 3: Build and Push Images

```bash
# Build and push both images
./scripts/build-images.sh --push

# Build only API
./scripts/build-images.sh --push --api-only

# Build only frontend
./scripts/build-images.sh --push --frontend-only

# Build with custom tag
./scripts/build-images.sh --push --tag v1.0.0
```

### Step 4: Verify Images

```bash
# Login to GHCR (if not already)
echo $GITHUB_TOKEN | docker login ghcr.io --username github --password-stdin

# Pull and verify
docker pull ghcr.io/ardenone/moltbook-api:latest
docker pull ghcr.io/ardenone/moltbook-frontend:latest

docker images | grep moltbook
```

## Image Details

### moltbook-api
- **Base Image**: node:18-alpine
- **Port**: 3000
- **Health Check**: HTTP GET /health
- **Size**: ~150MB compressed

### moltbook-frontend
- **Base Image**: node:18-alpine
- **Port**: 3000
- **Health Check**: HTTP GET /
- **Size**: ~200MB compressed
- **Build Output**: Next.js standalone

## Deployment

After pushing images, update your Kubernetes deployments to use the new images:

```yaml
# deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: moltbook-api
          image: ghcr.io/ardenone/moltbook-api:latest
        - name: moltbook-frontend
          image: ghcr.io/ardenone/moltbook-frontend:latest
```

## Troubleshooting

### Authentication Failed
```bash
# Ensure token has correct scopes
# Required: write:packages, read:packages

# Re-authenticate
echo $GITHUB_TOKEN | docker login ghcr.io --username github --password-stdin
```

### Build Context Issues
```bash
# Ensure you're in the project root
pwd  # Should show: .../moltbook-org

# Verify Dockerfiles exist
ls api/Dockerfile moltbook-frontend/Dockerfile
```

### Rate Limiting
GitHub has rate limits on container registry operations. If you hit limits:
- Wait for the quota to reset (typically 1 hour)
- Use authenticated pulls (counts against higher limit)
- Consider caching layers in CI/CD

## CI/CD Alternative

For automated builds, consider setting up GitHub Actions:

```yaml
# .github/workflows/build-images.yml
name: Build Container Images
on:
  push:
    branches: [main]
    tags: ['v*']
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - run: ./scripts/build-images.sh --push --tag ${GITHUB_REF##*/v}
```
