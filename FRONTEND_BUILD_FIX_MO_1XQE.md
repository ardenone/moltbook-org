# Frontend Build Fix: Next.js 16 Compatibility and External CI (mo-1xqe)

## Problem Summary

Frontend container image build was blocked by two issues:
1. **Next.js 16.1.6 compatibility**: Requires Node.js 20+ and has webpack compatibility issues
2. **Devpod storage issues**: Longhorn PVC filesystem corruption preventing Docker builds

## Solution Overview

**Use external CI/build system (GitHub Actions) for frontend image builds until devpod storage is fixed.**

## Current Status

### GitHub Actions CI/CD Workflow

- **Location**: `.github/workflows/build-images.yml`
- **Triggers**: Automatically on push to `main` branch when files in `api/`, `moltbook-frontend/`, or workflow itself change
- **Manual Trigger**: `gh workflow run build-images.yml`
- **Images Built**:
  - `ghcr.io/ardenone/moltbook-api:latest`
  - `ghcr.io/ardenone/moltbook-frontend:latest`

### Frontend Dockerfile Configuration

The Dockerfile at `moltbook-frontend/Dockerfile` is correctly configured:

```dockerfile
# Uses Node.js 20-alpine (supports Next.js 16)
FROM node:20-alpine AS builder

# Uses pnpm for package management
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile

# Builds with Turbopack for Next.js 16
RUN pnpm run build
```

### Next.js 16 Fixes in next.config.js

The `moltbook-frontend/next.config.js` includes:

1. **Turbopack enabled** (recommended for Next.js 16)
   ```js
   turbopack: {
     root: __dirname,
   }
   ```

2. **Webpack configuration** for node: prefixed imports
   ```js
   webpack: (config, { isServer }) => {
     // Handle node: prefixed imports
     config.resolve.alias[`node:async_hooks`] = 'async_hooks';
     // ... etc
   }
   ```

3. **React 19 compatibility**
   ```js
   reactStrictMode: false,  // Prevents double-invocation errors
   ```

## Deployment Configuration

The Kubernetes deployment at `k8s/frontend/deployment.yml` uses:

```yaml
image: ghcr.io/ardenone/moltbook-frontend:latest
```

The kustomization at `k8s/kustomization.yml` can use specific tags:

```yaml
images:
  - name: ghcr.io/ardenone/moltbook-frontend
    newName: ghcr.io/ardenone/moltbook-frontend
    newTag: latest  # or specific SHA like 'main-abc1234'
```

## How to Build and Deploy

### Option 1: Push to Main (Automatic)

```bash
# Make changes to moltbook-frontend/
git add .
git commit -m "feat: Update frontend"
git push origin main

# GitHub Actions automatically:
# 1. Builds the frontend image
# 2. Pushes to GHCR
# 3. Updates k8s/kustomization.yml with new image tags
# 4. ArgoCD detects changes and deploys
```

### Option 2: Manual Workflow Trigger

```bash
# Trigger build from devpod
gh workflow run build-images.yml

# Watch the build
gh run watch

# Or view in browser
gh run view --web
```

### Option 3: Build Locally (Requires Non-Devpod Environment)

```bash
# This WON'T work in devpod due to overlayfs limitations
# Use on a local machine with Docker installed:

export GITHUB_TOKEN=ghp_your_token_here
./scripts/build-images.sh --push --frontend-only
```

## Verification Steps

1. **Check if images exist in GHCR**:
   ```bash
   gh api /user/packages/container/moltbook-frontend/versions
   ```

2. **Check workflow status**:
   ```bash
   gh run list --workflow=build-images.yml --limit 5
   ```

3. **Verify deployment**:
   ```bash
   kubectl get pods -n moltbook -l app=moltbook-frontend
   kubectl logs -n moltbook -l app=moltbook-frontend --tail=50
   ```

## Devpod Storage Issue

### Current State

The devpod's Longhorn PVC has filesystem corruption causing:
- ENOENT errors during npm install
- Overlay filesystem errors during Docker builds
- node_modules corruption

### Temporary Solution

- Use GitHub Actions for all container image builds
- The external CI system has proper Docker environments

### Permanent Solution (Future)

- Recreate devpod with fresh PVC (see related beads)
- Consider migrating to local-path storage class

## Related Issues

- **Next.js 16 webpack error**: `Cannot read properties of undefined (reading 'issuerLayer')`
- **Devpod filesystem corruption**: See beads mo-11nw, mo-2lce, mo-2nn0
- **GitHub Actions workflow**: `.github/workflows/build-images.yml`

## Node.js Version Requirements

Next.js 16.1.6 requires Node.js >=20.9.0:
- Current Dockerfile: `node:20-alpine` (satisfies requirement)
- Devpod Node.js: v24.12.0 (satisfies requirement)

## References

- Next.js 16 Documentation: https://nextjs.org/docs
- Docker Build Guide: `DOCKER_BUILD.md`
- Build Workflow: `.github/workflows/build-images.yml`
- Kubernetes Manifests: `k8s/frontend/`
