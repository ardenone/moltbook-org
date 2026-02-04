# GitHub Push Permissions Required

## Issue Summary
User `jedarden` lacks push permissions to the following moltbook organization repositories:
- https://github.com/moltbook/api.git
- https://github.com/moltbook/moltbook-frontend.git

## Current Status

### Verified Permissions
```json
// moltbook/api
{
  "admin": false,
  "maintain": false,
  "pull": true,
  "push": false,
  "triage": false
}

// moltbook/moltbook-frontend
{
  "admin": false,
  "maintain": false,
  "pull": true,
  "push": false,
  "triage": false
}
```

### Organization Membership
- User `jedarden` is **NOT** a member of the `moltbook` organization
- User has read-only access to both repositories (public repos)

## Required Actions

### Option 1: Add as Organization Member (Recommended)
1. Repository owner invites `jedarden` to the `moltbook` organization
2. Grant appropriate role (Member or Owner)
3. Configure repository access for both repos with **Write** or **Maintain** permission

**Steps for organization owner:**
```bash
# Via GitHub UI:
# 1. Go to https://github.com/orgs/moltbook/people
# 2. Click "Invite member"
# 3. Enter: jedarden
# 4. Select role: Member (or Owner if full access needed)
# 5. After acceptance, go to Settings > Collaborators & teams for each repo
# 6. Add jedarden with "Write" permission
```

### Option 2: Add as Direct Collaborator
If organization membership is not desired, add as direct collaborator to each repository:

**Steps for repository owner:**
```bash
# Via GitHub CLI (run by repository admin):
gh api repos/moltbook/api/collaborators/jedarden -X PUT -f permission=push
gh api repos/moltbook/moltbook-frontend/collaborators/jedarden -X PUT -f permission=push

# Or via GitHub UI:
# 1. Go to https://github.com/moltbook/api/settings/access
# 2. Click "Add people"
# 3. Enter: jedarden
# 4. Select role: Write
# 5. Repeat for moltbook-frontend repository
```

## Impact

### Blocked Workflows
Without push permissions, the following workflows are blocked:
1. **Docker Image Builds**: Both repos have Dockerfiles that trigger GitHub Actions on push
2. **Direct Development**: Cannot push commits directly to moltbook repositories
3. **CI/CD Pipeline**: Cannot trigger automated builds and deployments

### Current Workaround
Local repositories are configured with two remotes:
- `origin`: https://github.com/ardenone/moltbook-org.git (has push access)
- `moltbook`: https://github.com/moltbook/api.git (read-only)

To push to the writable remote:
```bash
# In api directory
cd /home/coder/Research/moltbook-org/api
git push origin main

# In moltbook-frontend directory
cd /home/coder/Research/moltbook-org/moltbook-frontend
git push origin main
```

## Repository Owner Contact
The owner of the `moltbook` organization repositories needs to be contacted to grant permissions.

**To find the owner:**
```bash
gh api orgs/moltbook --jq '{login: .login, name: .name, email: .email, created: .created_at}'
```

## Next Steps
1. Identify the moltbook organization owner/admin
2. Request push permissions using one of the options above
3. Once granted, verify access: `gh api repos/moltbook/api --jq .permissions`
4. Push pending commits to trigger Docker image builds

## Technical Details

### Repository URLs
- API: https://github.com/moltbook/api
- Frontend: https://github.com/moltbook/moltbook-frontend

### User Details
- GitHub username: `jedarden`
- Token scopes: `delete_repo`, `gist`, `read:org`, `repo`, `workflow`
- Authentication: ✓ Valid (gho_**** token)

### Git Remotes Configuration
Both local repositories have been configured with the moltbook remotes:
```bash
# api/
origin    https://github.com/ardenone/moltbook-org.git
moltbook  https://github.com/moltbook/api.git

# moltbook-frontend/
origin    https://github.com/ardenone/moltbook-org.git
moltbook  https://github.com/moltbook/moltbook-frontend.git
```

---

**Created**: 2026-02-04
**Issue**: mo-2ik
**Status**: Awaiting repository admin action
**Verified**: 2026-02-04 by jedarden (pull access confirmed, push access required)
**Blocker Bead**: mo-2xz2 (PRIORITY 0 - BLOCKS Docker builds)
