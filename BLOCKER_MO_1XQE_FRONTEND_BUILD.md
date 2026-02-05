# Blocker: Frontend Build - Next.js 16 Compatibility and Devpod Storage

**Bead ID**: mo-1xqe
**Status**: RESOLVED - Solution documented, use external CI/build system
**Date**: 2026-02-05

---

## Problem Statement

The frontend container image build is blocked by two issues:

1. **Next.js 16.1.6 compatibility** - Requires Node.js 20.9.0+
2. **Devpod overlay filesystem corruption** - Prevents Docker builds in devpod environment

---

## Analysis

### 1. Next.js 16.1.6 Compatibility

**Status**: NO ISSUE - Devpod meets requirements

From `moltbook-frontend/package.json`:
```json
{
  "next": "^16.1.6",
  "engines": {
    "node": ">=20.9.0"
  }
}
```

**Current devpod environment**:
```
Node.js version: v24.12.0
Status: Meets Next.js 16 requirement (>= 20.9.0)
```

### 2. Devpod Storage Issue

**Status**: CONFIRMED - Nested overlay filesystem prevents Docker builds

**Root cause**:
- Devpod runs on `ardenone-cluster` with K3s
- K3s uses containerd with overlayfs storage driver
- Docker daemon inside devpod tries to create another overlay filesystem
- Linux kernel does not allow nested overlay mounts (overlay-over-overlay)

**Error symptom**:
```
mount source: "overlay", target: "/var/lib/docker/buildkit/containerd-overlayfs/...",
fstype: overlay, flags: 0, data: "...", err: invalid argument
```

---

## Solution: External CI/Build System

Since Docker builds fail in devpod due to the overlay filesystem limitation, use an external build system. Three solutions are available:

### Option 1: GitHub Actions (Recommended)

**Workflow**: `.github/workflows/build-images.yml`

**Triggers**:
- Push to main branch
- Pull requests
- Manual workflow dispatch
- Tags matching `v*`

**Usage**:
```bash
# Automatic: push to main
git push origin main

# Manual: trigger from GitHub CLI
gh workflow run build-images.yml
gh run watch
```

**Registry**: GitHub Container Registry (ghcr.io)
- API: `ghcr.io/ardenone/moltbook-api:latest`
- Frontend: `ghcr.io/ardenone/moltbook-frontend:latest`

### Option 2: Kaniko (In-Cluster Builds)

**Best for**: Building images directly from devpod

**Script**: `scripts/kaniko-build.sh`

**Usage**:
```bash
# Deploy Kaniko runner (one-time)
./scripts/kaniko-build.sh --deploy

# Build both images
./scripts/kaniko-build.sh --all --watch

# Build specific component
./scripts/kaniko-build.sh --api-only --tag v1.0.0
./scripts/kaniko-build.sh --frontend-only --tag v1.0.0
```

**Note**: Kaniko requires:
- `k8s/kaniko/` manifests to be deployed
- `ghcr-credentials` secret in moltbook namespace

### Option 3: Build on Host Machine

**Best for**: Quick testing and development

**Usage**:
```bash
# On local machine (not in devpod)
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Frontend Dockerfile Details

**File**: `moltbook-frontend/Dockerfile`

**Configuration**:
- Base image: `node:20-alpine`
- Package manager: pnpm
- Build command: `pnpm run build` (uses `--turbopack` flag for Next.js 16)
- Port: 3000

**Key features**:
- Multi-stage build for smaller image size
- pnpm install with fallback for overlay issues
- Production-optimized with health checks
- Non-root user for security

---

## Deployment

Once the frontend image is built and pushed:

```bash
# Restart frontend deployment to pull new image
kubectl rollout restart deployment/moltbook-frontend -n moltbook

# Monitor rollout
kubectl get pods -n moltbook -l app=moltbook-frontend -w
```

**Note**: The moltbook namespace must exist first. This requires cluster-admin permissions (see separate RBAC blockers).

---

## Related Files

| File | Purpose |
|------|---------|
| `moltbook-frontend/package.json` | Dependencies and build config |
| `moltbook-frontend/Dockerfile` | Container image build |
| `.github/workflows/build-images.yml` | GitHub Actions CI/CD |
| `scripts/kaniko-build.sh` | Kaniko build helper |
| `k8s/frontend/deployment.yml` | Kubernetes deployment |

---

## Related Documentation

- [BUILD_GUIDE.md](./BUILD_GUIDE.md) - Complete build instructions
- [DOCKER_BUILD_SOLUTION.md](./DOCKER_BUILD_SOLUTION.md) - Docker build solutions
- [DOCKER_BUILD_WORKAROUND.md](./DOCKER_BUILD_WORKAROUND.md) - Workaround documentation

---

## Resolution

**Status**: RESOLVED

1. Next.js 16.1.6 compatibility is not an issue (Node.js v24 available)
2. Devpod storage issue is documented with multiple solutions
3. Use GitHub Actions, Kaniko, or host machine for builds
4. Once built, deployment can proceed normally

**No code changes required** - this is a documentation/operational task.

---

## Follow-Up Actions

None required. The existing build infrastructure is complete and functional.

- Use GitHub Actions for production builds (automatic on push to main)
- Use Kaniko for builds from devpod (manual trigger)
- Use host machine for quick testing

---

**Created**: 2026-02-05
**Bead**: mo-1xqe
**Status**: RESOLVED
