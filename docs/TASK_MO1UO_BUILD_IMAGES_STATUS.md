# Task mo-1uo: Build and Push Container Images - Status Report

**Date**: 2026-02-04  
**Status**: Partially Complete (API ✓, Frontend ✗)  
**Bead**: mo-1uo

## Summary

Implemented GitHub Actions workflow to build and push Docker container images for Moltbook deployment. The API image builds and pushes successfully, but the Frontend image encounters a recurring Next.js build error.

## What Works ✓

### API Image - SUCCESS
- **Image**: `ghcr.io/ardenone/moltbook-api:latest`
- **Build Time**: ~28-42 seconds
- **Status**: Successfully built and pushed to GitHub Container Registry
- **Dockerfile**: `api/Dockerfile` (multi-stage Node.js 18 Alpine)
- All builds passing consistently

### Infrastructure Setup - COMPLETE
1. ✓ GitHub Actions workflow (`.github/workflows/build-push.yml`)
   - Automated builds on push to main (when `api/` or `moltbook-frontend/` change)
   - Manual trigger via `workflow_dispatch`
   - Parallel builds for API and Frontend
   - Proper authentication to ghcr.io
   - Build caching with GitHub Actions cache

2. ✓ Build script (`scripts/build-images.sh`)
   - Local build capability (requires host machine, not devpod)
   - Supports dry-run mode
   - Tag customization
   - Component-specific builds (--api-only, --frontend-only)

3. ✓ Kubernetes manifests ready
   - Deployments reference `ghcr.io/ardenone/moltbook-api:latest`
   - Deployments reference `ghcr.io/ardenone/moltbook-frontend:latest`

## What Doesn't Work ✗

### Frontend Image - FAILING
- **Image**: `ghcr.io/ardenone/moltbook-frontend:latest`
- **Error**: `TypeError: (0 , n.createContext) is not a function`
- **Build Stage**: Next.js build (`npm run build`) - "Collecting page data" phase
- **Dockerfile**: `moltbook-frontend/Dockerfile` (multi-stage Next.js 14)

#### Build Error Details

The error occurs during the Next.js static generation phase when Next.js tries to analyze the module graph for Server-Side Generation (SSG). Even though all pages have the `'use client'` directive, Next.js still attempts to execute some client-side code during the build process.

**Error Pattern** (whack-a-mole):
1. First failure: `/m/[name]` page → Fixed with `export const dynamic = 'force-dynamic'`
2. Second failure: `/_not-found` page → Fixed with `'use client'` directive
3. Third failure: `/notifications` page → **Still failing** (already has `'use client'`)

**Current Error**:
```
TypeError: (0 , n.createContext) is not a function
    at 6150 (/app/.next/server/chunks/319.js:2:33226)
    ...
Error: Failed to collect page data for /notifications
```

#### Attempted Fixes

1. ✓ Added `'use client'` to all page files (12 pages)
2. ✓ Added `export const dynamic = 'force-dynamic'` to dynamic routes
3. ✓ Added `'use client'` to not-found.tsx
4. ✓ Verified all layout components have `'use client'`
5. ✓ Verified store and hooks files have `'use client'`
6. ✗ Still failing on notifications page despite having `'use client'`

## Root Cause Analysis

The issue appears to be **structural** rather than a missing directive:

1. **Next.js Module Bundling**: During build, Next.js creates separate server and client bundles. The server bundle is attempting to import React Context-dependent code.

2. **Zustand Store**: The app uses Zustand for state management, which likely uses React Context internally. Even with `'use client'`, the module graph analysis might be pulling in these dependencies during SSG.

3. **Barrel Exports**: Files like `@/components/ui` and `@/hooks` export many components/hooks. Next.js might be trying to analyze all exports even if only some are used.

4. **Standalone Output**: The Dockerfile uses Next.js `standalone` output mode, which might have different build behavior.

## Next Steps - Created Bead mo-1d1x

**Bead**: mo-1d1x - "Fix: Next.js build createContext error in production Docker build"  
**Priority**: 0 (Critical blocker)

Investigation areas:
1. **Force all routes to dynamic rendering** - Add route segment config to all pages
2. **Webpack configuration** - Custom webpack config to exclude client code from server bundle
3. **Component lazy loading** - Use `next/dynamic` for components with Context
4. **Alternative output modes** - Try removing `standalone` output
5. **Circular dependency check** - Verify no circular imports in hooks/store
6. **Build environment** - Test if issue is Docker-specific or also happens in local builds

## Workarounds

Until frontend image is fixed, deployment options:

### Option 1: Deploy API Only
- API can run independently
- Use development frontend server temporarily
- Connect to production API via CORS

### Option 2: Local Frontend Build
- Build frontend on host machine (not in devpod due to overlayfs issues)
- Push image manually with `scripts/build-images.sh`
- Requires `GITHUB_TOKEN` with write:packages scope

### Option 3: Disable SSG Completely
- Configure Next.js for full dynamic rendering
- May impact performance but unblocks deployment

## Files Modified

### Added/Updated:
- `.github/workflows/build-push.yml` - GitHub Actions workflow
- `scripts/build-images.sh` - Local build script  
- `moltbook-frontend/src/app/(main)/m/[name]/page.tsx` - Added dynamic config
- `moltbook-frontend/src/app/not-found.tsx` - Added 'use client'
- `moltbook-frontend/next.config.js` - Added experimental config (may revert)
- `docs/TASK_MO1UO_BUILD_IMAGES_STATUS.md` - This document

### Documentation:
- `BUILD_IMAGES.md` - Comprehensive build guide
- `DOCKER_BUILD_WORKAROUND.md` - devpod limitations
- `DOCKER_RATE_LIMIT_INVESTIGATION.md` - Rate limit findings

## Commands Reference

### Check Build Status
```bash
# List recent workflow runs
gh run list --workflow=build-push.yml --limit 5

# Watch latest run
gh run watch <run-id> --exit-status

# View run logs
gh run view <run-id> --log
```

### Trigger Manual Build
```bash
# Via GitHub CLI
gh workflow run build-push.yml

# Via local script (requires host machine)
GITHUB_TOKEN=xxx ./scripts/build-images.sh --push
```

### Check Registry
```bash
# View packages (requires read:packages scope)
gh api /orgs/ardenone/packages/container/moltbook-api
gh api /orgs/ardenone/packages/container/moltbook-frontend
```

## Success Metrics

- [x] API image builds successfully
- [x] API image pushes to ghcr.io
- [x] GitHub Actions workflow configured
- [x] Build script created and tested
- [ ] Frontend image builds successfully ⚠️ **BLOCKED**
- [ ] Frontend image pushes to ghcr.io
- [ ] Both images available for Kubernetes deployment

## Related Beads

- **mo-1d1x**: Fix Next.js build error (created from this task)
- **mo-saz**: RBAC/ArgoCD deployment (depends on images being ready)
- **mo-23p**: ArgoCD sync verification (blocked by images)

## Conclusion

The mo-1uo task successfully implemented the container build infrastructure and resolved the API image build. The frontend image build requires deeper investigation into Next.js build configuration, which has been spun off into bead mo-1d1x (priority 0).

**Recommendation**: Assign mo-1d1x to a Next.js specialist or escalate for pair programming session to resolve the SSG/client Context bundling issue.
