# Task mo-1uo: Build and Push Container Images for Deployment

**Date**: 2026-02-04
**Status**: Partially Complete (API Success, Frontend Blocker)
**Bead ID**: mo-1uo

## Summary

Successfully set up and executed container image builds for the Moltbook project using GitHub Actions CI/CD pipeline. The API image was successfully built and pushed to GitHub Container Registry (ghcr.io). The Frontend build encountered a webpack bundling issue that requires further investigation.

## Completed Tasks

### 1. Infrastructure Setup
- [x] Verified Dockerfiles exist for both API and Frontend
- [x] Verified GitHub Actions workflow (`.github/workflows/build-push.yml`) is configured
- [x] Verified Kubernetes deployment manifests reference correct image registry (`ghcr.io/ardenone/*`)
- [x] Confirmed build script exists at `scripts/build-images.sh`

### 2. CI/CD Pipeline Verification
- [x] GitHub Actions workflow is configured to:
  - Build on push to `main` branch
  - Support manual workflow dispatch
  - Use `ghcr.io/ardenone` organization registry
  - Build both API and Frontend images in parallel

### 3. API Image - SUCCESS
- [x] API image successfully built
- [x] API image pushed to registry at:
  - `ghcr.io/ardenone/moltbook-api:latest`
  - `ghcr.io/ardenone/moltbook-api:main`
  - `ghcr.io/ardenone/moltbook-api:main-6695f6b`

### 4. Frontend Image - BLOCKER
- [ ] Frontend build failing with webpack bundling error
- [x] Created blocker bead: **mo-1kt0** - "Fix: Frontend Docker build failing with createContext webpack error"

## Frontend Build Issue Details

### Error
```
TypeError: (0 , r.createContext) is not a function
    at 6150 (/app/.next/server/chunks/150.js:1:259)
```

### Root Cause
During Docker build, Next.js webpack bundler is incorrectly mangling the React import for `createContext`. This happens during the "Collecting page data" phase when trying to pre-render pages.

### Attempted Fixes
1. Added `NEXT_TELEMETRY_DISABLED=1` to Dockerfile
2. Updated Next.js config to filter React from externals
3. Added `isrMemoryCacheSize: 0` to experimental config

### Pages Affected
All pages fail during pre-rendering:
- `/` (home)
- `/notifications`
- `/search`
- `/settings`
- `/submit`
- `/submolts`
- `/submolts/create`
- `/_not-found`
- `/auth/login`
- `/auth/register`

## Deployment Manifests

### API Deployment (`k8s/api/deployment.yml`)
```yaml
image: ghcr.io/ardenone/moltbook-api:latest
```

### Frontend Deployment (`k8s/frontend/deployment.yml`)
```yaml
image: ghcr.io/ardenone/moltbook-frontend:latest
```

Both manifests are correctly configured to use the `ghcr.io/ardenone` registry.

## Next Steps

1. **CRITICAL**: Fix frontend build issue (bead mo-1kt0)
   - Investigate webpack configuration for proper React bundling
   - Consider alternative approaches:
     - Use `output: 'export'` instead of `standalone`
     - Add proper webpack alias for React
     - Disable static generation entirely with `force-dynamic`

2. **Post-fix**: After frontend build succeeds:
   - Verify both images are accessible in GHCR
   - Update any hardcoded image references if needed
   - Test Kubernetes deployment with new images

## Files Modified

1. `moltbook-frontend/Dockerfile` - Added `NEXT_TELEMETRY_DISABLED=1`
2. `moltbook-frontend/next.config.js` - Updated webpack externals config

## References

- Build workflow: `.github/workflows/build-push.yml`
- API Dockerfile: `api/Dockerfile`
- Frontend Dockerfile: `moltbook-frontend/Dockerfile`
- Build guide: `BUILD_IMAGES.md`
- Blocker bead: **mo-1kt0**
