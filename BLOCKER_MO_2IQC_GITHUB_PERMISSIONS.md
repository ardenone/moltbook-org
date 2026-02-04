# Blocker mo-2iqc: GitHub Push Permissions for Container Image Builds

**Bead ID:** mo-2iqc
**Priority:** 0 (Critical)
**Status:** BLOCKED - Requires external action
**Date:** 2026-02-04

## Summary

User `jedarden` lacks push permissions to Moltbook organization repositories, preventing automated container image builds via GitHub Actions. This blocks the deployment pipeline for Moltbook.

## Affected Repositories

- https://github.com/moltbook/api
- https://github.com/moltbook/moltbook-frontend

## Error Details

```
remote: Permission to moltbook/api.git denied to jedarden.
fatal: unable to access 'https://github.com/moltbook/api.git/': The requested URL returned error: 403
```

## Impact

**Cannot push Dockerfiles to trigger GitHub Actions for automated container image builds.**

The following container images must be available for deployment:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

## Dockerfiles Ready

Both Dockerfiles are prepared and present in the moltbook-org repository:

### API Dockerfile
- **Location:** `/home/coder/Research/moltbook-org/api/Dockerfile`
- **Base Image:** `node:18-alpine`
- **Port:** 3000
- **Features:**
  - Multi-stage build for optimization
  - Non-root user execution (nodejs:1001)
  - Health check endpoint
  - Production-optimized dependencies

### Frontend Dockerfile
- **Location:** `/home/coder/Research/moltbook-org/moltbook-frontend/Dockerfile`
- **Base Image:** `node:20-alpine`
- **Port:** 3000
- **Features:**
  - Multi-stage build with Next.js compilation
  - Non-root user execution (nodejs:1001)
  - Health check on root path
  - Next.js production server (`npm start`)

## Required Action

**Moltbook organization owner must grant write access to `jedarden` for both repositories.**

### Steps for Organization Owner

1. Navigate to https://github.com/moltbook/api/settings/access
2. Click "Collaborators and teams"
3. Invite `jedarden` with **Write** permission
4. Repeat for https://github.com/moltbook/moltbook-frontend/settings/access

### Verification Steps

After permissions are granted, verify:

```bash
# Verify API repo access
cd /home/coder/Research/moltbook-org/api
git remote -v | grep moltbook
git push moltbook main  # Should succeed without 403 error

# Verify frontend repo access
cd /home/coder/Research/moltbook-org/moltbook-frontend
git remote -v | grep moltbook
git push moltbook main  # Should succeed without 403 error
```

## Current Git Remote Configuration

### moltbook-frontend
```
fork	https://github.com/jedarden/moltbook-frontend.git (fetch)
fork	https://github.com/jedarden/moltbook-frontend.git (push)
moltbook	https://github.com/moltbook/moltbook-frontend.git (fetch)
moltbook	https://github.com/moltbook/moltbook-frontend.git (push)
origin	https://github.com/ardenone/moltbook-org.git (fetch)
origin	https://github.com/ardenone/moltbook-org.git (push)
```

## Alternative Workaround (if permissions cannot be granted)

If organization permissions cannot be granted, consider:

1. **Create GitHub Actions workflows in the fork** (`jedarden/moltbook-*` repos)
2. **Push to ardenone/moltbook-org** and trigger builds from there
3. **Manual image builds** using local Docker or CI/CD from other sources

## Related Documentation

- BUILD_IMAGES.md - Container image build process
- DOCKER_BUILD.md - Docker build procedures
- GITHUB_PERMISSIONS_REQUIRED.md - Detailed GitHub permissions requirements
- GITHUB_PERMISSIONS_BLOCKER.md - Related permission blocker
- GITHUB_ADMIN_ACTION_REQUIRED.md - Admin action summary

## Next Steps (Once Unblocked)

1. Push Dockerfiles to moltbook/api and moltbook/moltbook-frontend
2. Verify GitHub Actions workflows are triggered
3. Confirm images are pushed to `ghcr.io/ardenone/*`
4. Update Kubernetes manifests to reference new image locations
5. Deploy to apexalgo-iad cluster

---

**Resolution:** This bead will be marked complete when `jedarden` has verified successful push access to both moltbook organization repositories.
