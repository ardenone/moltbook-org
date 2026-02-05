# Docker Build Workaround for Devpod Environment

**Issue**: mo-jgo - Docker builds fail in devpod environment
**Date**: 2026-02-04
**Updated**: 2026-02-05 - Added Kaniko solution
**Status**: ✅ **MULTIPLE SOLUTIONS AVAILABLE** - See [DOCKER_BUILD_SOLUTIONS.md](./DOCKER_BUILD_SOLUTIONS.md) for complete guide

---

## Problem Summary

Docker image builds fail when executed inside the devpod environment with:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

### Root Cause

This is **NOT a Docker Hub rate limit issue** despite the bead title. The actual problem:

1. **Nested Overlayfs**: Devpod runs inside Kubernetes with overlayfs storage
2. **Docker-in-Docker Limitation**: Docker daemon tries to create nested overlay filesystem
3. **Kernel Restriction**: Linux kernel doesn't support nested overlayfs mounts  
4. **Podman Also Affected**: Podman socket unavailable in containerized environment

### What Doesn't Work in Devpod

❌ Local Docker builds
❌ Disabling BuildKit
❌ Using Podman
❌ Changing storage drivers

---

## ✅ Solution: Use GitHub Actions

### Current Workflow Status

⚠️ The GitHub Actions workflow (`.github/workflows/build-images.yml`) is **configured but failing**.

**Issue**: All 34 workflow runs failed with "Server Error" from `docker/metadata-action@v5`

**Follow-up Bead**: **mo-1na** - Fix GitHub Actions workflow failures

### Once Workflow is Fixed

Trigger builds automatically by pushing to main:

```bash
git add .
git commit -m "feat: Update code"
git push origin main
```

Or trigger manually:

```bash
gh workflow run build-images.yml
gh run watch
```

---

## ✅ NEW: Kaniko Solution (Bead mo-3t8p)

**Best for**: Building images directly from devpod without leaving the container

Kaniko is a daemonless container image builder that works in Kubernetes without Docker daemon or nested overlay issues.

### Quick Start

```bash
# 1. Deploy Kaniko runner (one-time setup)
kubectl apply -f k8s/kaniko/

# 2. Create GHCR credentials
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  -n moltbook

# 3. Build images using helper script
./scripts/kaniko-build.sh --all

# Or trigger directly with kubectl
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh
```

### See Also

- `k8s/kaniko/README.md` - Detailed Kaniko documentation
- `scripts/kaniko-build.sh` - Helper script for triggering builds
- [DOCKER_BUILD_SOLUTIONS.md](./DOCKER_BUILD_SOLUTIONS.md) - Complete comparison of all solutions

---

## Alternative: Build on Host Machine

Build images on your host machine (not in devpod), then push:

```bash
# On host machine (MacOS/Linux workstation)
cd ~/moltbook-org
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## ✅ Safe Build Wrapper (Bead mo-1nh)

A new **safe build wrapper** has been added that automatically detects devpod environments and prevents the overlay filesystem error with helpful guidance.

### Usage

```bash
# Use the safe build wrapper instead of build-images.sh directly
./scripts/build-images-safe.sh [options]
```

### What It Does

- Automatically detects when running in devpod/Kubernetes containerized environment
- Prevents Docker builds with clear, actionable error message
- Suggests alternatives (GitHub Actions, host machine build, pre-built images)
- Delegates to build-images.sh when running on host machine

### Detection Methods

The wrapper checks for:
- Kubernetes service account token (`/var/run/secrets/kubernetes.io/serviceaccount/token`)
- Devpod environment variables (`DEVPOD`, `DEVPOD_NAME`)
- Container markers (`/.dockerenv`, `/run/.containerenv`)
- Devpod hostname patterns (`devpod-*`, `*-workspace-*`)

---

## Related Issues

| Bead | Title | Priority | Status |
|------|-------|----------|--------|
| mo-jgo | Docker Hub rate limit (misdiagnosed) | P1 | ✅ Documented |
| mo-1na | GitHub Actions workflow failures | P1 | ✅ Completed |
| mo-1nh | Fix: Docker build overlay filesystem error in devpod | P1 | ✅ COMPLETED |
| mo-3bol | Fix: Docker build environment - node_modules ENOTEMPTY error | P1 | ✅ COMPLETED |
| mo-3t8p | Fix: Docker overlay filesystem prevents image builds in devpod | P1 | ✅ **COMPLETED** |

---

## Summary

- **Problem**: Nested overlayfs prevents Docker builds in devpod
- **Not the Problem**: Docker Hub rate limits (red herring)
- **Solutions Available**:
  1. **GitHub Actions** - Automated CI/CD builds (recommended for production)
  2. **Kaniko** - In-cluster daemonless builds (recommended for devpod)
  3. **Host Machine** - Manual local builds (for quick testing)
- **Workaround**: Build on host machine and push manually
- **Safe Build Wrapper**: Prevents the error automatically (bead mo-1nh)

---

**Created**: 2026-02-04
**Bead**: mo-jgo
**Updated**: 2026-02-04 - Added safe build wrapper (bead mo-1nh)
**Updated**: 2026-02-05 - Added Kaniko solution (bead mo-3t8p)
**Updated**: 2026-02-05 - Clarified node_modules ENOTEMPTY error (bead mo-3bol)
**Status**: ✅ **MULTIPLE SOLUTIONS AVAILABLE** - See [DOCKER_BUILD_SOLUTIONS.md](./DOCKER_BUILD_SOLUTIONS.md)

---

## Node_modules ENOTEMPTY Error (Bead mo-3bol)

### Clarification

The task description mentioned "node_modules corruption" with ENOTEMPTY errors during npm install. After investigation:

1. **Local builds work fine** - `npm run build` completes successfully in the devpod
2. **Docker builds fail** - The ENOTEMPTY error occurs during Docker build, not local npm
3. **Root cause confirmed** - This is the overlay filesystem issue, not actual node_modules corruption

### Why ENOTEMPTY Occurs During Docker Build

The error message `ENOTEMPTY: directory not empty, rmdir node_modules/...` during Docker builds is a symptom of:

1. Docker BuildKit tries to manage node_modules as part of layer caching
2. When npm install attempts to remove/clean directories, the overlay filesystem doesn't handle it properly
3. The nested overlay (devpod + Docker) causes filesystem operations to fail

### Current Workarounds in Dockerfile

The `moltbook-frontend/Dockerfile` already includes workarounds:

```dockerfile
# Use npm ci instead of npm install for cleaner installs
RUN npm ci --legacy-peer-deps --no-audit --no-fund || \
    (rm -rf node_modules package-lock.json && npm install --legacy-peer-deps --no-audit --no-fund)
```

These workarounds help but cannot fully overcome the nested overlay limitation.

### Solution Remains: Use GitHub Actions

The ENOTEMPTY error is resolved by using GitHub Actions for Docker builds, which don't have the nested overlay limitation.

**Status**: ✅ **RESOLVED** - GitHub Actions workflow builds successfully
