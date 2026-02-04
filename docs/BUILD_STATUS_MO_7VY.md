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

The frontend container image build is failing with a React Context error during the Next.js prerendering phase.

### Error Details
```
TypeError: Cannot read properties of null (reading 'useContext')
    at B.useContext (/app/.next/server/chunks/452.js:39:1357264)
    at m (/app/.next/server/pages/_error.js:1:26448)
```

### Error Location
- Failing pages: `/500`, `/404`
- Failing file: `/app/.next/server/chunks/452.js:39`
- React module: `react-dom-server.browser.production.min.js`

### Root Cause Analysis

The error appears to be related to webpack configuration changes for handling `node:` prefixed modules. The `next.config.js` was recently modified to:
1. Add externals configuration for `node:` prefixed modules
2. Add resolve plugins for handling `node:` prefix
3. Add fallback for Node.js built-ins including `buffer`

These changes may have inadvertently affected how React and React DOM are bundled, causing the prerendering to fail.

### Related Bead
- **mo-3rve**: Fix: Frontend build fails with React Context error during prerendering (Priority 0 - Critical)

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
