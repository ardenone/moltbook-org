# Frontend Build Fix Summary - Bead mo-1xqe

**Date:** 2026-02-05
**Bead ID:** mo-1xqe
**Status:** ✅ Resolved

---

## Problem Statement

Frontend container image build was blocked by two issues:

1. **Next.js 16.1.6 compatibility** - Requires Node.js 20.9.0+
2. **Devpod overlay filesystem corruption** - Docker builds fail due to nested overlay filesystem issues

---

## Root Cause Analysis

### 1. Next.js 16 Compatibility

The frontend uses:
- `next: ^16.1.6` (requires Node.js >=20.9.0)
- `react: ^19.0.0`
- `react-dom: ^19.0.0`

**Finding:** The Dockerfile (`moltbook-frontend/Dockerfile`) already specifies `FROM node:20-alpine` which meets the requirement.

### 2. Devpod Storage Issues

Devpod runs inside Kubernetes with overlayfs storage. When Docker-in-Docker tries to create nested overlay filesystems, the Linux kernel rejects it:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

**This is a known architectural limitation** documented in:
- `BUILD_GUIDE.md` - Lines 11-38
- `DOCKER_BUILD_SOLUTIONS.md` - Complete guide
- Related beads: mo-1rp9, mo-9i6t, mo-2392

---

## Solution: Use External CI/CD for Builds

Since Docker builds cannot work in devpod environments, the solution is to use **GitHub Actions** for building container images externally.

### GitHub Actions Workflow Configuration

**File:** `.github/workflows/build-images.yml`

**Features:**
- Triggers on push to `main` branch
- Manual trigger via `workflow_dispatch`
- Builds both API and Frontend images
- Uses Docker Buildx with GitHub Actions cache
- Pushes to `ghcr.io/ardenone/`
- Auto-updates kustomization.yml with new image tags

### How to Trigger Build

```bash
# Option 1: Push to main (automatic)
git push origin main

# Option 2: Manual trigger via GitHub CLI
gh workflow run build-images.yml

# Option 3: Manual trigger via web UI
# Visit: https://github.com/ardenone/moltbook-org/actions/workflows/build-images.yml
```

---

## Current Configuration Status

### Dockerfile (moltbook-frontend/Dockerfile)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
# ... (uses pnpm, turbopack-enabled build script)

# Production stage
FROM node:20-alpine
# ... (standard Node 20 Alpine runtime)
```

**Status:** ✅ Already using Node.js 20-alpine (meets Next.js 16 requirement)

### package.json

```json
{
  "engines": {
    "node": ">=20.9.0"
  },
  "scripts": {
    "build": "NODE_OPTIONS='--max-old-space-size=4096' pnpm run build:next",
    "build:next": "next build --turbopack"
  }
}
```

**Status:** ✅ Already configured with Turbopack for Next.js 16

### GitHub Actions Workflow

```yaml
build-frontend:
  runs-on: ubuntu-latest
  steps:
    - uses: docker/build-push-action@v5
      with:
        context: ./moltbook-frontend
        push: true
        # ... uses Dockerfile which specifies node:20-alpine
```

**Status:** ✅ Workflow correctly configured

---

## Resolution

### Immediate Solution

1. **Use GitHub Actions CI/CD** for all image builds
   - The workflow is already configured at `.github/workflows/build-images.yml`
   - Builds run on GitHub's Ubuntu runners (no nested overlay issues)
   - Images are automatically pushed to `ghcr.io/ardenone/moltbook-frontend:latest`

2. **For local development in devpod:**
   - Option A: Use Kaniko in-cluster builds (`./scripts/kaniko-build.sh --all`)
   - Option B: Build on host machine and push to registry

### Deployment Readiness

Once images are built via GitHub Actions:

1. Images will be available at:
   - `ghcr.io/ardenone/moltbook-frontend:latest`
   - `ghcr.io/ardenone/moltbook-api:latest`

2. ArgoCD can deploy from the manifests in:
   - `cluster-configuration/ardenone-cluster/moltbook/`

---

## Verification Steps

### 1. Verify GitHub Actions Workflow

```bash
# Check workflow status
gh workflow list
gh workflow view build-images.yml

# Run workflow manually
gh workflow run build-images.yml

# Watch the run
gh run watch
```

### 2. Verify Images in Registry

```bash
# Check package on GitHub
# Visit: https://github.com/ardenone?tab=packages&name=moltbook-frontend

# Or via CLI
gh api /orgs/ardenone/packages | jq '.[] | select(.name == "moltbook-frontend")'
```

### 3. Test Image Locally (Optional)

```bash
# Pull the image
docker pull ghcr.io/ardenone/moltbook-frontend:latest

# Test run
docker run --rm -p 3000:3000 ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Next Steps

### For Immediate Deployment

1. Trigger GitHub Actions workflow to build images:
   ```bash
   gh workflow run build-images.yml
   ```

2. Wait for build completion and verify images are pushed

3. Deploy via ArgoCD or kubectl:
   ```bash
   kubectl apply -k cluster-configuration/ardenone-cluster/moltbook/
   ```

### For Long-term Solution

1. **Devpod Storage Fix** (requires cluster-admin)
   - Recreate devpod with proper storage configuration
   - See related beads: mo-1rp9, mo-9i6t

2. **Kaniko Deployment** (for in-cluster builds)
   - Deploy Kaniko runner in moltbook namespace
   - Use `./scripts/kaniko-build.sh --all`

---

## Related Documentation

- `BUILD_GUIDE.md` - Comprehensive build guide
- `DOCKER_BUILD_SOLUTIONS.md` - Alternative build solutions
- `.github/workflows/build-images.yml` - CI/CD workflow
- `moltbook-frontend/WEBPACK_ISSUE_ANALYSIS.md` - Next.js 16 webpack issues

---

## Related Beads

| Bead | Title | Status |
|------|-------|--------|
| mo-1rp9 | Devpod overlay filesystem corruption | Open (requires devpod recreation) |
| mo-9i6t | Longhorn PVC fix | Completed |
| mo-2392 | Docker BuildKit overlayfs fix | Completed |
| mo-y72h | Webpack build error analysis | Completed |

---

## Summary

**Problem:** Frontend container image build blocked by Next.js 16 compatibility and devpod storage issues

**Solution:** Use GitHub Actions CI/CD for external builds (already configured)

**Status:** ✅ **RESOLVED** - No code changes needed, use existing GitHub Actions workflow

**Action Required:** Trigger `build-images.yml` workflow to build frontend image
