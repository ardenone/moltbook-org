# Blocker Status: mo-2iqc - Grant GitHub push permissions for container image builds

**Bead ID**: mo-2iqc
**Status**: 🔴 BLOCKED - Requires Moltbook Organization Owner Action
**Priority**: P0 (Critical)
**Date**: 2026-02-04

## Executive Summary

User `jedarden` lacks push permissions to moltbook organization repositories on GitHub. This prevents pushing Dockerfiles to trigger GitHub Actions for automated container image builds, which are required for Moltbook deployment.

## Affected Repositories

| Repository | URL | Required Image | Status |
|------------|-----|----------------|--------|
| moltbook/api | https://github.com/moltbook/api | ghcr.io/moltbook/api:latest | 🔴 No push access |
| moltbook/moltbook-frontend | https://github.com/moltbook/moltbook-frontend | ghcr.io/moltbook/moltbook-frontend:latest | 🔴 No push access |

## Current State (Verified 2026-02-04)

### Dockerfiles Ready

Both Dockerfiles are complete and ready for GitHub Actions:

**API Dockerfile**: `/home/coder/Research/moltbook-org/api/Dockerfile`
- Multi-stage build (node:18-alpine)
- Production-optimized (npm ci --omit=dev)
- Non-root user (nodejs:1001)
- Health check on port 3000
- Secure best practices

**Frontend Dockerfile**: `/home/coder/Research/moltbook-org/moltbook-frontend/Dockerfile`
- Multi-stage build (node:20-alpine)
- Next.js production build
- Non-root user (nodejs:1001)
- Health check on port 3000
- Telemetry disabled (NEXT_TELEMETRY_DISABLED=1)

### Error Message

```
remote: Permission to moltbook/api.git denied to jedarden.
fatal: unable to access 'https://github.com/moltbook/api.git/': The requested URL returned error: 403
```

### Repository Access Status

Current git remote configuration shows:
- **Fork exists**: `https://github.com/jedarden/moltbook-frontend.git` (read/write)
- **Upstream exists**: `https://github.com/moltbook/moltbook-frontend.git` (fetch only)
- **User**: jedarden
- **Permission level**: Read-only on moltbook org repos

## Root Cause

The `jedarden` GitHub account does not have write access to the moltbook organization repositories. This is typically because:

1. User is not a member of the moltbook organization
2. User is a member but has only read permissions
3. Repository settings restrict push access to owners/admins only

## Impact

Without push permissions:
- ❌ Cannot push Dockerfiles to moltbook/api repository
- ❌ Cannot push Dockerfiles to moltbook/moltbook-frontend repository
- ❌ Cannot trigger GitHub Actions workflows for container builds
- ❌ Cannot publish images to `ghcr.io/moltbook/*`
- ❌ Moltbook deployment cannot proceed (deployment requires these images)

## Resolution Path

### Moltbook Organization Owner Action Required

A moltbook organization owner must grant write access to `jedarden`:

#### Option 1: Grant Organization Membership (Recommended)

1. Go to: https://github.com/orgs/moltbook/people
2. Click "Invite member"
3. Enter username: `jedarden`
4. Select role: **Member** (not Owner, not Admin)
5. Select repository access: **Write access** to `api` and `moltbook-frontend`
6. Send invitation

#### Option 2: Grant Collaborator Access (Alternative)

If full organization membership is not appropriate, grant collaborator access to each repository:

**For moltbook/api:**
1. Go to: https://github.com/moltbook/api/settings/access
2. Click "Add people"
3. Enter username: `jedarden`
4. Select permission: **Write**
5. Click "Add name"

**For moltbook/moltbook-frontend:**
1. Go to: https://github.com/moltbook/moltbook-frontend/settings/access
2. Click "Add people"
3. Enter username: `jedarden`
4. Select permission: **Write**
5. Click "Add name"

### Verification After Access Granted

Once access is granted, verify with:

```bash
# Test push access to moltbook/api
cd /home/coder/Research/moltbook-org/api
git push moltbook main

# Test push access to moltbook/moltbook-frontend
cd /home/coder/Research/moltbook-org/moltbook-frontend
git push moltbook main
```

### Expected GitHub Actions Workflow

Once push access is granted and Dockerfiles are pushed:

1. **Push Dockerfile to moltbook/api**
   - Triggers: `.github/workflows/docker-build.yml` (if configured)
   - Builds: `ghcr.io/moltbook/api:latest`
   - Publishes: GitHub Container Registry

2. **Push Dockerfile to moltbook/moltbook-frontend**
   - Triggers: `.github/workflows/docker-build.yml` (if configured)
   - Builds: `ghcr.io/moltbook/moltbook-frontend:latest`
   - Publishes: GitHub Container Registry

## Alternative: Manual Image Build (If GitHub Actions Not Available)

If GitHub Actions workflows are not set up, images can be built manually from the moltbook-org repo:

```bash
# Build API image
cd /home/coder/Research/moltbook-org/api
docker build -t ghcr.io/moltbook/api:latest .
docker push ghcr.io/moltbook/api:latest

# Build Frontend image
cd /home/coder/Research/moltbook-org/moltbook-frontend
docker build -t ghcr.io/moltbook/moltbook-frontend:latest .
docker push ghcr.io/moltbook/moltbook-frontend:latest
```

**Note**: This requires GitHub token authentication for ghcr.io push.

## Related Documentation

- `BLOCKER_MO_3AW.md` - Ardenone-cluster namespace blocker
- `MOLTBOOK_RBAC_BLOCKER_STATUS.md` - Complete RBAC blocker analysis
- `cluster-configuration/ardenone-cluster/moltbook/` - Moltbook deployment manifests

## Related Beads

- **mo-2iqc** (P0) - This bead: GitHub push permissions blocker
- **mo-3aw** (P0) - Ardenone-cluster namespace blocker
- **mo-4n69** (P0) - ADMIN: Cluster Admin Action - Apply NAMESPACE_SETUP_REQUEST.yml
- **mo-3vfo** (P0) - Cluster Admin: Create moltbook namespace in ardenone-cluster

## Security Considerations

Granting write access to `jedarden` for these repositories:
- ✅ **Appropriate**: User is developing Moltbook and needs to push code/Dockerfiles
- ✅ **Limited scope**: Only affects moltbook/api and moltbook/moltbook-frontend
- ✅ **Reversible**: Access can be revoked at any time
- ✅ **Audit trail**: All pushes are logged with user identity

## Next Steps

1. **Moltbook Owner**: Grant write access to jedarden (organization membership or collaborator)
2. **Verification**: Confirm push access with test push to both repositories
3. **Push Dockerfiles**: Push prepared Dockerfiles to moltbook repositories
4. **GitHub Actions**: Ensure workflows are configured for automated builds
5. **Deploy Images**: Use ghcr.io/moltbook/* images in Kubernetes deployment
6. **Update Bead**: Mark this bead as CLOSED after successful push

---

**Last Updated**: 2026-02-04
**Status**: 🔴 BLOCKER - Awaiting Moltbook organization owner action
**Priority**: P0 (Critical)
**Estimated Time**: 2 minutes (one-time setup)

---

## Task mo-2iqc Summary

This task has documented the GitHub permissions blocker preventing push access to moltbook organization repositories.

**Verification performed (2026-02-04):**
- ✅ Confirmed API Dockerfile exists at `/home/coder/Research/moltbook-org/api/Dockerfile`
- ✅ Confirmed Frontend Dockerfile exists at `/home/coder/Research/moltbook-org/moltbook-frontend/Dockerfile`
- ✅ Verified both Dockerfiles follow best practices (multi-stage, non-root user, health checks)
- ✅ Confirmed git remote configuration shows `moltbook` remote (read-only access)
- ✅ Confirmed user `jedarden` has fork but no push access to upstream

**Required action:** Moltbook organization owner must grant write access to `jedarden` for both repositories.

**Dockerfiles are ready:** No changes needed to Dockerfiles - they are complete and production-ready. Awaiting GitHub permissions to push them.
