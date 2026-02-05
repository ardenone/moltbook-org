# Bead mo-1qkj Summary: Docker OverlayFS Issue Resolution

**Bead ID**: mo-1qkj
**Title**: Fix: Docker overlayfs issue in devpod for container image builds
**Status**: ✅ RESOLVED
**Date**: 2026-02-05

---

## Problem Statement

The devpod environment uses overlayfs (k3s containerd snapshotter). Docker's overlayfs driver cannot work on top of another overlay filesystem - this is a nested overlay limitation.

**Error**: `mount source: overlay... err: invalid argument`

---

## Root Cause Analysis

### The Nested OverlayFS Problem

1. **Devpod Environment**: Runs inside Kubernetes with overlayfs storage
2. **Docker-in-Docker**: When Docker daemon builds images, it creates nested overlay mounts
3. **Kernel Restriction**: Linux kernel doesn't support nested overlayfs mounts
4. **Failure Point**: Any attempt to build Docker images in devpod fails with "invalid argument"

### What Doesn't Work

- ❌ Local Docker builds in devpod
- ❌ Disabling BuildKit
- ❌ Using Podman (socket unavailable in containerized environment)
- ❌ Changing Docker storage drivers

---

## Solutions Implemented

### 1. GitHub Actions CI/CD (Primary Solution)

**Status**: ✅ Working
**Location**: `.github/workflows/build-push.yml`

**Features**:
- Automated builds on push to main
- Builds both API and Frontend images
- Pushes to GHCR (ghcr.io/ardenone)
- Updates Kustomization image tags automatically
- Build caching via GitHub Actions cache
- SBOM and provenance generation

**Recent Runs**: All successful (as of 2026-02-05)

### 2. Kaniko In-Cluster Builds (Devpod Solution)

**Status**: ✅ Implemented
**Location**: `k8s/kaniko/`

**Features**:
- Daemonless image builder (no Docker daemon required)
- Runs in standard Kubernetes pods
- Works without nested overlay issues
- Build scripts for API, Frontend, or both
- Layer caching support
- GHCR authentication via Kubernetes secrets

**Usage**:
```bash
# Deploy Kaniko runner
kubectl apply -f k8s/kaniko/

# Trigger build
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh
```

### 3. Host Machine Builds (Fallback)

For local testing and development, build on host machine (not in devpod):

```bash
# On host machine
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

docker login ghcr.io -u github --password-stdin
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Node.js Version Fix

**Task Description Mentioned**: "Frontend build fails due to Next.js 16 requiring Node.js >=20.9.0 but Dockerfile uses node:18-alpine"

**Current Status**: ✅ Fixed
- `moltbook-frontend/Dockerfile` uses `node:20-alpine` (required for Next.js 16)
- `api/Dockerfile` uses `node:18-alpine` (sufficient for Express.js)
- Related bead mo-2mz3 was closed (stale - already fixed in commit e10447b)

---

## Dockerfile Improvements

### API Dockerfile

```dockerfile
FROM node:18-alpine AS builder
# Build stage with production dependencies
FROM node:18-alpine
# Production stage with health checks
# Node 18 is sufficient for Express.js API
```

### Frontend Dockerfile

```dockerfile
FROM node:20-alpine AS builder
# Build stage with npm ci and build
FROM node:20-alpine
# Production stage with all dependencies
# Includes workarounds for overlay issues
RUN npm ci --legacy-peer-deps --no-audit --no-fund || \
    (rm -rf node_modules package-lock.json && npm install --legacy-peer-deps --no-audit --no-fund)
```

---

## Comparison Matrix

| Solution | Pros | Cons | Best For |
|----------|------|------|----------|
| **GitHub Actions** | Native runners, no Docker issues, CI/CD integration, automated | External dependency | Production CI/CD |
| **Kaniko** | In-cluster, no nested overlay, fast local builds | Requires cluster resources | Devpod development |
| **Host Machine** | Full Docker control, fastest | Requires leaving devpod | Local testing |

---

## Related Beads

| Bead | Title | Status |
|------|-------|--------|
| mo-1na | GitHub Actions workflow failures | ✅ Completed |
| mo-1nh | Fix: Docker build overlay filesystem error in devpod | ✅ Completed |
| mo-3bol | Fix: Docker build environment - node_modules ENOTEMPTY error | ✅ Completed |
| mo-3t8p | Fix: Docker overlay filesystem prevents image builds in devpod | ✅ Completed |
| mo-2mz3 | Fix: Update Dockerfile to use Node.js 20+ for Next.js 16 | ✅ Closed (stale) |
| mo-312j | Fix: Frontend build fails with createContext webpack error | ✅ Completed |

---

## Documentation Files

- `DOCKER_BUILD_WORKAROUND.md` - Comprehensive workaround documentation
- `k8s/kaniko/README.md` - Kaniko deployment guide
- `scripts/build-images-safe.sh` - Safe build wrapper with environment detection
- `scripts/kaniko-build.sh` - Kaniko build helper script

---

## Verification

To verify the solutions are working:

```bash
# 1. Check GitHub Actions status
gh run list --workflow build-push.yml

# 2. Check Kaniko deployment (if deployed)
kubectl get deployment -n moltbook kaniko-build-runner

# 3. Verify images on GHCR
gh api /user/packages | jq -r '.[] | select(.name | contains("moltbook")) | .name'
```

---

## Conclusion

The Docker overlayfs issue in devpod is **fully resolved** with multiple working solutions:

1. **GitHub Actions** - Automated CI/CD builds (recommended for production)
2. **Kaniko** - In-cluster daemonless builds (recommended for devpod)
3. **Host Machine** - Manual local builds (for quick testing)

The Node.js version blocker mentioned in the task description has also been resolved:
- Frontend uses `node:20-alpine` (required for Next.js 16)
- API uses `node:18-alpine` (sufficient for Express.js)
- Related bead mo-2mz3 was closed (stale - already fixed in commit e10447b)

---

**Created**: 2026-02-05
**Bead**: mo-1qkj
**Status**: ✅ RESOLVED
