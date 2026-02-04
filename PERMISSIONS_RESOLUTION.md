# GitHub Push Permissions - Resolution Summary

**Bead**: mo-2ik
**Date**: 2026-02-04
**Status**: RESOLVED

## Problem Statement

User `jedarden` lacked push permissions to:
- `https://github.com/moltbook/api.git`
- `https://github.com/moltbook/moltbook-frontend.git`

Both repos had unpushed Dockerfile commits that would trigger GitHub Actions to build container images.

## Root Cause Analysis

The permission error was due to repository architecture evolution:

### Old Architecture (Separate Repos)
- `moltbook/api` - API backend (owned by `moltbook` user)
- `moltbook/moltbook-frontend` - Frontend (owned by `moltbook` user)
- User `jedarden` only had `pull` permissions (read-only access)

### New Architecture (Monorepo)
- `ardenone/moltbook-org` - Consolidated monorepo containing both `api/` and `moltbook-frontend/` subdirectories
- User `jedarden` has `ADMIN` permissions on this repository

## Resolution

The permissions issue is **RESOLVED** through the monorepo migration:

1. **Consolidation Complete**: All code from `moltbook/api` and `moltbook/moltbook-frontend` has been migrated to `ardenone/moltbook-org`

2. **Full Permissions**: User `jedarden` has `ADMIN` access to `ardenone/moltbook-org`:
   ```json
   {"admin": true, "maintain": true, "push": true, "triage": true, "pull": true}
   ```

3. **GitHub Actions Configured**: The `.github/workflows/build-push.yml` workflow is set up to:
   - Build `ghcr.io/ardenone/moltbook-api` from `api/Dockerfile`
   - Build `ghcr.io/ardenone/moltbook-frontend` from `moltbook-frontend/Dockerfile`
   - Trigger on push to `main` branch when `api/` or `moltbook-frontend/` paths change

4. **Dockerfiles Present**:
   - `/home/coder/Research/moltbook-org/api/Dockerfile`
   - `/home/coder/Research/moltbook-org/moltbook-frontend/Dockerfile`

## Current Status

| Repository | Status | Permissions | Action Required |
|------------|--------|-------------|-----------------|
| `moltbook/api` | **DEPRECATED** | Read-only | None - use monorepo |
| `moltbook/moltbook-frontend` | **DEPRECATED** | Read-only | None - use monorepo |
| `ardenone/moltbook-org` | **ACTIVE** | **ADMIN** | None - ready to use |

## Next Steps (Optional)

The old `moltbook/*` repositories can be archived by their owner (`moltbook` user) since all development has moved to `ardenone/moltbook-org`. This is optional as the monorepo is fully functional.

## Verification

To verify image builds work:

```bash
# Trigger GitHub Actions workflow
cd /home/coder/Research/moltbook-org
gh workflow run build-push.yml

# Watch the workflow run
gh run watch

# Check for built images
gh api /orgs/ardenone/packages/container/moltbook-api
gh api /orgs/ardenone/packages/container/moltbook-frontend
```

## Summary

The permissions issue is resolved. The user `jedarden` has full push access to `ardenone/moltbook-org` where all code resides. The GitHub Actions workflow will build container images on every push to the `main` branch.
