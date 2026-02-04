# Docker Hub Rate Limit Investigation - mo-jgo

**Bead**: mo-jgo - Fix: Docker Hub rate limit blocking image builds
**Date**: 2026-02-04
**Status**: ✅ RESOLVED - No rate limit issue found

## Summary

Investigation into reported Docker Hub rate limits blocking Moltbook image builds. **Conclusion: Docker Hub rate limits are NOT the blocker**. The actual issue is a Next.js build failure tracked in mo-2mj.

## Findings

### 1. Base Images Pull Successfully

GitHub Actions logs show `node:18-alpine` base image pulls complete without rate limit errors:

```
#5 [internal] load metadata for docker.io/library/node:18-alpine
#7 resolve docker.io/library/node:18-alpine@sha256:8d6421...done
```

No `429 Too Many Requests` or rate limit warnings observed in any workflow run.

### 2. GitHub Actions Has Caching Configured

The workflow `.github/workflows/build-push.yml` already implements layer caching to mitigate rate limits:

```yaml
- name: Build and push API image
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

This caches base images and layers, preventing repeated pulls from Docker Hub.

### 3. Actual Build Failure is Next.js Related

GitHub Actions run 21680489235 shows the real error:

```
> Build error occurred
Error: Failed to collect page data for /_not-found
    at /app/node_modules/next/dist/build/utils.js:1258:15
```

TypeScript compilation succeeds (`✓ Compiled successfully`), but Next.js build process fails during page data collection.

### 4. Local Builds Blocked by Overlay Filesystem

Attempting local builds in devpod environment fails with:

```
ERROR: mount source: "overlay" ... err: invalid argument
```

This is a known limitation of nested overlay filesystems in containerized devpods, NOT a rate limit issue.

## Configuration Status

### ✅ Docker Hub Rate Limit Mitigations Already In Place

1. **GitHub Actions Caching**: Configured and working
2. **Correct Base Images**: Using official `node:18-alpine` (not incorrect `ghcr.io/library/node`)
3. **Build Context**: Running in GitHub Actions with no rate limit issues

### ❌ Incorrect Configurations Fixed

Previous attempts to fix rate limits introduced invalid base image references:
- `ghcr.io/library/node:18-alpine` (does NOT exist - GHCR doesn't have library namespace mirrors)

These have been reverted to correct `node:18-alpine` from Docker Hub.

## Recommendations

### 1. Close mo-jgo as Resolved (No Action Needed)

Docker Hub rate limits are not blocking builds. The current configuration is correct and working for base image pulls.

### 2. Focus on mo-2mj (P0 - Critical)

**New bead created**: mo-2mj - "Fix: Next.js build failing with '/_not-found' page data collection error"

This is the actual blocker preventing frontend image builds. Root cause is Next.js configuration or missing page handling.

### 3. Do NOT Use Local Builds in Devpod

Local Docker builds will continue to fail due to overlay filesystem limitations. Always use GitHub Actions for building images.

## Alternative Solutions (Not Needed)

If rate limits become an issue in the future, consider:

1. **Docker Hub Authentication**: Add DOCKER_USERNAME and DOCKER_PASSWORD secrets to GitHub Actions
   ```yaml
   - name: Login to Docker Hub
     uses: docker/login-action@v3
     with:
       username: ${{ secrets.DOCKER_USERNAME }}
       password: ${{ secrets.DOCKER_PASSWORD }}
   ```

2. **Alternative Base Images**: Use Chainguard's cgr.dev (rate-limit-free)
   ```dockerfile
   FROM cgr.dev/chainguard/node:latest
   ```

3. **Self-hosted Registry**: Mirror frequently-used base images to GHCR

## Conclusion

**mo-jgo can be marked as complete with "no action needed"** - Docker Hub rate limits are not occurring and proper mitigations are already in place. The real work should focus on mo-2mj to fix the Next.js build error.

## References

- GitHub Actions workflow: `.github/workflows/build-push.yml`
- Failed run with Next.js error: 21680489235
- Dockerfiles: `api/Dockerfile`, `moltbook-frontend/Dockerfile`
- Actual blocker: mo-2mj (created 2026-02-04)
