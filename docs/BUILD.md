# Moltbook Container Image Build Guide

## Overview

Moltbook requires two container images to be built and pushed to GitHub Container Registry (GHCR):
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

## Devpod Build Limitation

**CRITICAL**: Container builds **CANNOT** be performed inside devpods due to overlay filesystem restrictions.

### The Problem
Devpods run as containers inside Kubernetes (container-in-container). Building Docker images requires nested overlay filesystem which is not supported by the Linux kernel overlay driver.

### Error when building in devpod:
```
failed to mount: mount source: "overlay", target: "/var/...", fstype: overlay, flags: 0,
data: "...", err: invalid argument
```

## Build Options

### Option 1: GitHub Actions (Recommended - Fully Automated)

**Workflow:** `.github/workflows/build-push.yml`

**Triggers:**
- Push to `main` branch when files in `api/`, `moltbook-frontend/`, or workflow change
- Version tags (e.g., `v1.0.0`) for release builds
- Manual trigger via `workflow_dispatch`
- Pull requests to `main` (build only, no push)

**Features:**
- Runs on native Ubuntu VMs with full Docker support
- Automatic caching for faster builds
- Integrated GHCR authentication
- Automatically updates `k8s/kustomization.yml` with new image tags
- SBOM and provenance for security

**Usage:**
```bash
# Automatic - push to main
git push origin main

# Manual trigger via GitHub CLI
gh workflow run build-push.yml

# Or trigger via GitHub web UI
# https://github.com/ardenone/moltbook-org/actions/workflows/build-push.yml
```

### Option 2: Kaniko (Kubernetes-Native Builds)

**Best for:** Building images directly within the Kubernetes cluster without external dependencies.

**Prerequisites:**
- kubectl configured for the cluster
- GHCR credentials secret in moltbook namespace

**Setup:**
```bash
# Create GHCR credentials secret
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  -n moltbook

# Deploy kaniko-build-runner
kubectl apply -f k8s/kaniko/
```

**Usage:**
```bash
# Build both images
./scripts/kaniko-build.sh --all --watch

# Build only API
./scripts/kaniko-build.sh --api-only --tag v1.0.0

# Build only Frontend
./scripts/kaniko-build.sh --frontend-only --watch
```

**Kaniko Benefits:**
- Works inside Kubernetes (no Docker daemon required)
- No privileged mode needed
- GitOps compatible (uses Deployment, not Job)
- Layer caching support

### Option 3: Local Machine

Build on your local development machine with Docker Desktop/Podman installed.

**Prerequisites:**
- Docker or Podman installed
- GitHub Personal Access Token with `write:packages` and `read:packages` scopes
  - Create at: https://github.com/settings/tokens

**Usage:**
```bash
# Set your GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Build and push both images
./scripts/build-images.sh --push

# Build only API
./scripts/build-images.sh --push --api-only

# Build only Frontend
./scripts/build-images.sh --push --frontend-only

# Build with custom tag
./scripts/build-images.sh --push --tag v1.0.0

# Build without pushing (dry run)
./scripts/build-images.sh --dry-run
```

## Deployment

After images are built and pushed, ArgoCD will automatically sync deployments that use the `latest` tag.

For specific version tags, update `k8s/kustomization.yml`:

```yaml
images:
  - name: ghcr.io/ardenone/moltbook-api
    newName: ghcr.io/ardenone/moltbook-api
    newTag: v1.0.0  # or specific SHA like 'main-abc1234'
  - name: ghcr.io/ardenone/moltbook-frontend
    newName: ghcr.io/ardenone/moltbook-frontend
    newTag: v1.0.0
```

## Image Details

### moltbook-api
- **Base Image:** node:18-alpine
- **Port:** 3000
- **Health Check:** HTTP GET /health
- **Size:** ~150MB compressed

### moltbook-frontend
- **Base Image:** node:20-alpine
- **Port:** 3000
- **Health Check:** HTTP GET /
- **Size:** ~200MB compressed
- **Build Output:** Next.js production build

## Troubleshooting

### GitHub Actions Build Failing

Check workflow logs:
```bash
gh run list --workflow=build-push.yml --limit 1
gh run view <run-id> --log
```

Common issues:
- Dockerfile errors (test locally with `docker build`)
- Missing dependencies (check package.json)

### Kaniko Build Failing

Check deployment status:
```bash
kubectl get pods -n moltbook -l app=kaniko-build-runner

# View build logs
kubectl logs -f deployment/kaniko-build-runner -n moltbook
```

Common issues:
- Missing GHCR credentials (create `ghcr-credentials` secret)
- Insufficient resources (check CPU/memory limits)

### Local Build Fails with Overlay Error

This is expected in devpod environments. Use GitHub Actions or Kaniko instead.

### Images Not Pulling in Kubernetes

Verify images exist on GHCR:
- https://github.com/ardenone?tab=packages&name=moltbook-api
- https://github.com/ardenone?tab=packages&name=moltbook-frontend

Check imagePullSecrets:
```bash
kubectl get secrets -n moltbook | grep ghcr
```

## Quick Reference

| Method | Build Environment | Automation | Best For |
|--------|------------------|------------|----------|
| GitHub Actions | Native Ubuntu VM | Fully automatic | Production deployments |
| Kaniko | Kubernetes cluster | Manual/Scheduled | Cluster-local builds |
| Local Machine | Docker Desktop/Podman | Manual | Testing/Development |

## See Also

- [GitHub Actions Workflow](../.github/workflows/build-push.yml)
- [Kaniko Deployment](../k8s/kaniko/)
- [API Dockerfile](../api/Dockerfile)
- [Frontend Dockerfile](../moltbook-frontend/Dockerfile)
- [Kubernetes Manifests](../k8s/)
