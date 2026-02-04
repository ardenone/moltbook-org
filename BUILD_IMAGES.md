# Moltbook Container Images - Build and Push Guide

**Bead**: mo-1uo - Fix: Build and push container images for deployment
**Date**: 2026-02-04

## Overview

This guide explains how to build and push the Moltbook container images to GitHub Container Registry (ghcr.io). The images are now under the `ardenone` organization.

## Image Registry

**Organization**: `ardenone` (GitHub organization)
**Registry**: `ghcr.io` (GitHub Container Registry)

### Images

| Component | Image Name | Purpose |
|-----------|------------|---------|
| API Backend | `ghcr.io/ardenone/moltbook-api:latest` | Node.js Express API |
| Frontend | `ghcr.io/ardenone/moltbook-frontend:latest` | Next.js 14 frontend |

## Method 1: GitHub Actions (Recommended)

The easiest way to build and push images is via GitHub Actions. The workflow is already configured.

### Prerequisites

1. The repository must be pushed to `https://github.com/ardenone/moltbook-org`
2. GitHub Actions must be enabled for the repository
3. The repository must have `packages: write` permission enabled

### Triggering the Build

The `.github/workflows/build-push.yml` workflow runs automatically on:

- Push to `main` branch when files in `api/` or `moltbook-frontend/` directories change
- Manual trigger via `workflow_dispatch` in GitHub Actions UI

### Manual Trigger via GitHub CLI

```bash
# Trigger the workflow manually
gh workflow run build-push.yml

# List workflow runs
gh run list --workflow=build-push.yml

# Watch the latest run
gh run watch
```

## Method 2: Safe Build Wrapper (NEW!)

⚠️ **PROTECTED** - Prevents the overlay filesystem error with automatic detection!

A safe build wrapper script automatically detects when you're in a devpod environment and prevents the build with helpful guidance.

### Using the Safe Build Wrapper

```bash
# Use this wrapper instead of calling build-images.sh directly
./scripts/build-images-safe.sh [options]

# Examples:
./scripts/build-images-safe.sh --dry-run      # Will show error message in devpod
./scripts/build-images-safe.sh --push         # Will show error message in devpod
```

### What It Does

- **Automatically detects devpod environment** (Kubernetes service account, container markers, hostname patterns)
- **Prevents builds with clear error messaging** if running in devpod
- **Suggests alternatives** (GitHub Actions, host machine build, pre-built images)
- **Delegates to build-images.sh** if running on host machine

### Devpod Detection

The wrapper checks for:
- Kubernetes service account token (`/var/run/secrets/kubernetes.io/serviceaccount/token`)
- Devpod environment variables (`DEVPOD`, `DEVPOD_NAME`)
- Container markers (`/.dockerenv`, `/run/.containerenv`)
- Devpod hostname patterns (`devpod-*`, `*-workspace-*`)

## Method 3: Local Build on Host Machine

### Prerequisites

- Docker or Podman installed and running **on host machine** (not in containerized devpod)
- GitHub Personal Access Token with `write:packages` and `read:packages` scopes

### Build Script Usage

```bash
# Show help
./scripts/build-images.sh --help

# Build images only (dry run, no push)
./scripts/build-images.sh --dry-run

# Build and push images
GITHUB_TOKEN=your_token_here ./scripts/build-images.sh --push

# Build only API image
GITHUB_TOKEN=your_token_here ./scripts/build-images.sh --push --api-only

# Build only Frontend image
GITHUB_TOKEN=your_token_here ./scripts/build-images.sh --push --frontend-only

# Build with custom tag
GITHUB_TOKEN=your_token_here ./scripts/build-images.sh --push --tag v1.0.0
```

## Verifying Images

### Check if Images Exist

```bash
# Using GitHub CLI
gh api /orgs/ardenone/packages/container/moltbook-api
gh api /orgs/ardenone/packages/container/moltbook-frontend
```

## Kubernetes Deployment

Once images are pushed, the Kubernetes deployment manifests are already configured to use `ghcr.io/ardenone/*` images.

### Deploy to Kubernetes

```bash
# Apply manifests
kubectl apply -k /home/coder/Research/moltbook-org/k8s/

# Watch pods
kubectl get pods -n moltbook -w
```

## Troubleshooting

### Image Pull Errors

If you see `ImagePullBackOff` or `ErrImagePull`:

1. Verify images exist with GitHub CLI
2. Check if registry is accessible from cluster
3. Verify image visibility (public by default)

### Build Failures

If GitHub Actions fails:

1. Check Actions tab in GitHub repository
2. Verify `packages: write` permission is enabled
3. Check workflow logs for specific errors

## Security Notes

1. **Never commit GITHUB_TOKEN to git** - use environment variables or GitHub Secrets
2. **Images are public by default** - don't include secrets in images
3. **Use SealedSecrets** for Kubernetes secrets (already implemented)

## Summary

| Method | Best For | Devpod Compatible | Automation |
|--------|----------|-------------------|------------|
| GitHub Actions | Production deployments | N/A | Fully automatic |
| Safe Build Wrapper | Protected local builds | ✅ Yes (prevents error) | Manual |
| Host Machine Build | Local testing on host | N/A | Semi-automatic |

**Recommended**:
- **Production**: Use GitHub Actions for fully automated CI/CD
- **Devpod Development**: Use Safe Build Wrapper to prevent overlay filesystem errors
- **Host Development**: Use build-images.sh directly on host machine

## Related Documentation

- **`DOCKER_BUILD_WORKAROUND.md`** - ⚠️ **READ THIS FIRST** for overlay filesystem error details
- `DEPLOYMENT_READY.md` - Deployment prerequisites
- `DEPLOYMENT_STATUS.md` - Current deployment status
- `scripts/build-images-safe.sh` - Safe build wrapper with devpod detection
- `scripts/build-images.sh` - Original host machine build script
