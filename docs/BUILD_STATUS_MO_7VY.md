# Container Image Build Status - mo-7vy

**Date:** 2026-02-04
**Bead:** mo-7vy (Build: Container images for moltbook-api and moltbook-frontend)

## Summary

Attempted to build and push container images to GHCR. The **API image was successfully built and pushed**, but the **frontend build is failing** due to a React Context error during prerendering.

## Current Status

| Component | Image | Status | Notes |
|-----------|-------|--------|-------|
| API | `ghcr.io/ardenone/moltbook-api:latest` | ✅ Built & Pushed | Successfully built via GitHub Actions |
| Frontend | `ghcr.io/ardenone/moltbook-frontend:latest` | ❌ Build Failed | React Context error during prerendering |

## API Image - SUCCESS

The API container image was successfully built and pushed to GHCR:
- **Build Run:** 21683255103
- **Build Time:** ~32 seconds
- **Image:** `ghcr.io/ardenone/moltbook-api:latest`
- **Tags Pushed:** `latest`, `main`, `main-de9478c`

### Dockerfile Location
- `api/Dockerfile`

### Image Details
- Base: `node:18-alpine`
- Port: 3000
- Health Check: HTTP GET /health
- Size: ~150MB compressed

## Frontend Image - BLOCKED

The frontend container image build is failing due to multiple compatibility issues.

### Current Error (Latest Build)

```
npm error `npm ci` can only install packages when your package.json and package-lock.json are in sync.
npm error Invalid: lock file's eslint-config-next@15.1.6 does not satisfy eslint-config-next@16.1.6
npm error Invalid: lock file's next@15.1.6 does not satisfy next@16.1.6
npm error Invalid: lock file's @next/eslint-plugin-next@15.1.6 does not satisfy @next/eslint-plugin-next@16.1.6
```

### Root Causes

1. **package-lock.json out of sync**: The lock file has `next@15.1.6` but package.json specifies `next@16.1.6`
2. **Node.js version mismatch**: Next.js 16.1.6 requires Node.js `>=20.9.0` but Dockerfile uses `node:18-alpine`
3. **Lock file mismatch**: Multiple packages are out of sync (eslint-config-next, sharp, @next/swc-* packages)

### Environment Issues

- **Current Node version**: `v18.20.8`
- **Next.js 16.1.6 requirement**: `>=20.9.0`
- **Dockerfile base image**: `node:18-alpine` (needs upgrade to `node:20-alpine` or `node:22-alpine`)

### Required Fixes

1. **Regenerate package-lock.json**: Run `npm install` to sync with package.json
2. **Update Dockerfile base image**: Change from `node:18-alpine` to `node:20-alpine` or higher
3. **Version alignment**: Decide on Next.js version strategy:
   - **Option A**: Downgrade to Next.js 14.x (stable, production-ready)
   - **Option B**: Upgrade to Next.js 16.x (latest, requires Node.js 20+)
4. **Commit updated lock file**: Ensure git state is clean before triggering build

### Related Beads
- **mo-azqd**: Fix: Frontend build blocked by Next.js 16.1.6 compatibility issues (Priority 0 - Critical)
- **mo-3rve**: Fix: Frontend build fails with React Context error during prerendering (Priority 0 - Critical)
- **mo-10ni**: Setup: Configure GITHUB_TOKEN for container image builds (Priority 0 - Critical)

## Build Method

Images were built using GitHub Actions CI/CD:
- **Workflow:** `.github/workflows/build-push.yml`
- **Triggered via:** `gh workflow run build-push.yml`

## Alternative Build Options

### 1. Manual Build (Requires GITHUB_TOKEN)
```bash
export GITHUB_TOKEN=your_token_here
./scripts/build-images.sh --push
```

### 2. GitHub Actions Web UI
Visit: https://github.com/ardenone/moltbook-org/actions/workflows/build-push.yml
Click "Run workflow" → Select `main` branch → Click "Run workflow"

### 3. GitHub CLI
```bash
gh workflow run build-push.yml
```

## Blockers

### Primary Blocker
**mo-3rve** - Frontend build failure (React Context error during prerendering)
- Status: Created
- Priority: 0 (Critical)
- Impact: Frontend container image cannot be built or deployed

### Secondary Blocker
**mo-10ni** - GITHUB_TOKEN not configured in devpod environment
- Status: Created
- Priority: 0 (Critical)
- Note: Workaround available via GitHub Actions

## Verification

To verify the API image is available:
```bash
curl -I https://ghcr.io/v2/ardenone/moltbook-api/manifests/latest
```

Or visit: https://github.com/ardenone?tab=packages&name=moltbook-api

## Next Steps

1. **Resolve mo-3rve** - Fix the frontend build React Context error
2. Re-run the build workflow to push frontend image
3. Verify both images are accessible on GHCR
4. Proceed with deployment

## Related Beads

- **mo-7vy** (this bead): Build: Container images for moltbook-api and moltbook-frontend
- **mo-3rve**: Fix: Frontend build fails with React Context error during prerendering
- **mo-10ni**: Setup: Configure GITHUB_TOKEN for container image builds
