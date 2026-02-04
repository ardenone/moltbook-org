# GitHub Permissions Blocker - Manual Admin Action Required

## Status
**BLOCKER** - Requires manual action by moltbook GitHub organization owner/admin

## Summary
User `jedarden` lacks push permissions to moltbook organization repositories. This is blocking Docker image builds via GitHub Actions.

## Current Permissions (Verified 2026-02-04)

| Repository | Pull | Push | Admin | Triage | Maintain |
|------------|------|------|-------|--------|----------|
| moltbook/api | ✅ | ❌ | ❌ | ❌ | ❌ |
| moltbook/moltbook-frontend | ✅ | ❌ | ❌ | ❌ | ❌ |

## Impact
- **Docker builds blocked**: Cannot push commits to trigger GitHub Actions
- **Development blocked**: Cannot push directly to moltbook repos
- **CI/CD blocked**: Cannot trigger automated builds

## Current Workaround
Using forked repos for push access:
- `origin`: https://github.com/ardenone/moltbook-org.git (writable)
- `moltbook`: https://github.com/moltbook/api.git (read-only)

## Action Required by moltbook Organization Owner

### Option 1: Add as Organization Member (Recommended)

**Via GitHub Web UI:**
1. Navigate to: https://github.com/orgs/moltbook/people
2. Click **"Invite member"**
3. Enter username: `jedarden`
4. Select role: **Member** (or Owner if full access needed)
5. After user accepts invitation:
   - Go to https://github.com/moltbook/api/settings/access
   - Add `jedarden` with **Write** or **Maintain** permission
   - Repeat for https://github.com/moltbook/moltbook-frontend/settings/access

### Option 2: Add as Direct Collaborator

**Via GitHub Web UI:**

For each repository (api and moltbook-frontend):
1. Navigate to repository Settings > Access
   - API: https://github.com/moltbook/api/settings/access
   - Frontend: https://github.com/moltbook/moltbook-frontend/settings/access
2. Click **"Add people"**
3. Enter username: `jedarden`
4. Select role: **Write**
5. Click **"Add [username]"**

**Via GitHub CLI (run by repository admin):**

```bash
# Add jedarden as collaborator with push permission
gh api repos/moltbook/api/collaborators/jedarden -X PUT -f permission=push
gh api repos/moltbook/moltbook-frontend/collaborators/jedarden -X PUT -f permission=push
```

## Verification Steps

After permissions are granted, verify:

```bash
# Check API permissions
gh api repos/moltbook/api --jq '.permissions'

# Check frontend permissions
gh api repos/moltbook/moltbook-frontend --jq '.permissions'
```

Expected output should include `"push": true`

## Related Beads
- **mo-1le** - This task: Admin action request for push permissions (current bead)
- **mo-2xz2** - Docker build blocker caused by missing permissions (PRIORITY 0)
- **mo-2ik** - Original permission investigation and documentation

## Task Completion Status
The task mo-1le is **complete** - documentation is verified and comprehensive. The actual permission grant requires:
1. A human with admin access to the `moltbook` GitHub organization
2. Manual action via GitHub UI or CLI (see "Action Required" section above)

This is an **external dependency** that cannot be automated by the worker system.

## Technical Details

### Repository URLs
- API: https://github.com/moltbook/api
- Frontend: https://github.com/moltbook/moltbook-frontend

### User Details
- GitHub username: `jedarden`
- Current token scopes: `delete_repo`, `gist`, `read:org`, `repo`, `workflow`
- Note: `admin:org` scope would be needed if jedarden were to grant permissions to themselves (not applicable - requires org owner)

---

**Created**: 2026-02-04
**Bead ID**: mo-2l68
**Priority**: 0 (BLOCKER)
**Status**: Awaiting manual admin action
