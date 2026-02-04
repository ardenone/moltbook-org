# Blocker mo-2iqc: GitHub Push Permissions for Container Image Builds

**Bead ID:** mo-2iqc
**Priority:** 0 (Critical)
**Status:** PARTIALLY RESOLVED - Using monorepo approach
**Date:** 2026-02-04
**Last Updated:** 2026-02-04

## Summary

User `jedarden` lacks push permissions to Moltbook organization repositories (`moltbook/api` and `moltbook/moltbook-frontend`). However, this is **partially resolved** by using the monorepo approach with `ardenone/moltbook-org`, where push access is available.

## Affected Repositories (Blocked Access)

- https://github.com/moltbook/api (Cannot push)
- https://github.com/moltbook/moltbook-frontend (Cannot push)

## Error Details

```
remote: Permission to moltbook/moltbook-frontend.git denied to jedarden.
fatal: unable to access 'https://github.com/moltbook/moltbook-frontend.git/': The requested URL returned error: 403
```

## Current Resolution: Monorepo Approach

**The container image builds are working via `ardenone/moltbook-org` monorepo.**

### Git Remote Configuration

```
origin	https://github.com/ardenone/moltbook-org.git (fetch/push)  # WORKS
moltbook	https://github.com/moltbook/moltbook-frontend.git (fetch/push)  # 403 ERROR
fork	https://github.com/jedarden/moltbook-frontend.git (fetch/push)  # Fork
```

### GitHub Actions Workflow

**Location:** `.github/workflows/build-push.yml`
**Triggers:** Push to `main` branch in `ardenone/moltbook-org`

**Image Destinations:**
- `ghcr.io/ardenone/moltbook-api:latest` (NOT ghcr.io/moltbook/*)
- `ghcr.io/ardenone/moltbook-frontend:latest` (NOT ghcr.io/moltbook/*)

## Dockerfiles Ready

Both Dockerfiles are present in the moltbook-org repository:

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

## Remaining Issues

### 1. Image Repository Naming
Images are published to `ghcr.io/ardenone/*` instead of `ghcr.io/moltbook/*`. This may cause:
- Confusion about image ownership
- Potential naming conflicts
- Inconsistency with expected image locations

### 2. Upstream Sync
Cannot push changes back to `moltbook/moltbook-frontend` upstream repository. This blocks:
- Contributing changes back to the upstream project
- Maintaining fork synchronization
- Collaborative development via moltbook organization

## Optional: Granting Access to Upstream

If the Moltbook organization owner wants to grant `jedarden` push access:

### Steps for Organization Owner

1. Navigate to https://github.com/moltbook/moltbook-frontend/settings/access
2. Click "Collaborators and teams"
3. Invite `jedarden` with **Write** permission
4. Repeat for https://github.com/moltbook/api/settings/access (if it exists)

### Verification Steps

```bash
# Verify upstream repo access
cd /home/coder/Research/moltbook-org
git push --dry-run moltbook main  # Should succeed without 403 error
```

## Alternative: Maintain Current Monorepo Approach

**Recommendation:** Continue using the monorepo approach with `ardenone/moltbook-org`.

**Advantages:**
- Already working
- Control over image naming and publishing
- No dependency on external organization permissions
- Consolidated build pipeline

**Considerations:**
- Update any references from `ghcr.io/moltbook/*` to `ghcr.io/ardenone/*`
- Document the image repository locations clearly
- Ensure Kubernetes manifests use correct image references

## Current Status

- [x] Dockerfiles created and committed
- [x] GitHub Actions workflow configured in `ardenone/moltbook-org`
- [x] Push access to `ardenone/moltbook-org` verified
- [ ] (Optional) Push access to `moltbook/moltbook-frontend` upstream
- [ ] Images published to GHCR (will happen on next push to main)

## Related Documentation

- `.github/workflows/build-push.yml` - Container image build workflow
- `k8s/kustomization.yml` - Kubernetes manifests with image references

## Next Steps

1. **Verify images build and publish correctly** on next push to `ardenone/moltbook-org`
2. **Update Kubernetes manifests** to use `ghcr.io/ardenone/*` image references
3. **(Optional) Request upstream access** if collaboration via moltbook organization is desired

---

**Resolution Status:** PARTIALLY RESOLVED
- Container images can be built via `ardenone/moltbook-org`
- Upstream `moltbook/*` repositories remain inaccessible
- No action required unless upstream collaboration is needed
