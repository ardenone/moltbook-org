# GitHub Admin Action Required: Grant Push Permissions to jedarden

## Status: 🔴 BLOCKER - Requires Moltbook Organization Owner/Admin

---

## 🚨 ADDITIONAL BLOCKER: Cluster Admin Action Required for ArgoCD Installation

**Status**: 🔴 BLOCKER - Requires Kubernetes Cluster Admin

The Moltbook deployment to ardenone-cluster is also blocked by missing Kubernetes RBAC permissions. The devpod ServiceAccount needs cluster-admin access to install ArgoCD.

### Required Cluster Admin Action

```bash
# Grant cluster-admin to devpod ServiceAccount
kubectl create clusterrolebinding devpod-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=devpod:default
```

**Alternative**: Apply the full RBAC manifest:
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
```

### Related Beads

- **mo-y5o** (P0) - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
- **mo-21sg** (P0) - CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation
- See `k8s/ARGOCD_INSTALL_BLOCKER_SUMMARY.md` for full details

---

### Overview

User `jedarden` lacks push permissions to the moltbook organization repositories. This is blocking Docker image builds via GitHub Actions, which are essential for deploying the Moltbook platform.

**This is a ONE-TIME setup action.** Once completed, future development will work automatically.

---

## 🚀 Quick Start (For Moltbook Org Owners/Admins)

### Option 1: Add as Organization Member (Recommended)

**Via GitHub Web UI:**

1. Navigate to: https://github.com/orgs/moltbook/people
2. Click **"Invite member"**
3. Enter username: `jedarden`
4. Select role: **Member** (or Owner if full access needed)
5. After user accepts invitation:
   - Go to https://github.com/moltbook/api/settings/access
   - Add `jedarden` with **Write** or **Maintain** permission
   - Go to https://github.com/moltbook/moltbook-frontend/settings/access
   - Add `jedarden` with **Write** or **Maintain** permission

### Option 2: Add as Direct Collaborator (Without Organization Membership)

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

---

## ✅ Verification

After permissions are granted, verify with:

```bash
# Check API permissions
gh api repos/moltbook/api --jq '.permissions'

# Check frontend permissions
gh api repos/moltbook/moltbook-frontend --jq '.permissions'
```

**Expected output should include**:
```json
{
  "admin": false,
  "maintain": false,
  "pull": true,
  "push": true,
  "triage": false
}
```

---

## 📋 Current Permissions State (Verified 2026-02-04)

| Repository | Pull | Push | Admin | Triage | Maintain |
|------------|------|------|-------|--------|----------|
| moltbook/api | ✅ | ❌ | ❌ | ❌ | ❌ |
| moltbook/moltbook-frontend | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 🎯 Impact of This Blocker

### What's Blocked Without Push Permissions

1. **Docker Image Builds**: Both repos have Dockerfiles that trigger GitHub Actions on push
2. **Direct Development**: Cannot push commits directly to moltbook repositories
3. **CI/CD Pipeline**: Cannot trigger automated builds and deployments

### Pending Work

The following commits are ready to push once permissions are granted:
- **moltbook/api**: Dockerfile for containerized deployment
- **moltbook/moltbook-frontend**: Dockerfile for containerized deployment

These changes will trigger GitHub Actions to build and push Docker images to ghcr.io.

---

## 🔒 Current Workaround

While waiting for permissions, the following workaround is in place:

### Using Mirror Repository

Local repositories are configured with two remotes:
- `origin`: https://github.com/ardenone/moltbook-org.git (writable)
- `moltbook`: https://github.com/moltbook/[repo].git (read-only)

To push to the writable remote:
```bash
# In api directory
cd /home/coder/Research/moltbook-org/api
git push origin main

# In moltbook-frontend directory
cd /home/coder/Research/moltbook-org/moltbook-frontend
git push origin main
```

**Note**: This workaround only solves the immediate problem of pushing code. It does **not** trigger the GitHub Actions workflows that build Docker images, which requires pushes to the moltbook organization repositories.

---

## 📚 Related Documentation

### In This Repository

- `GITHUB_PERMISSIONS_BLOCKER.md` - Detailed blocker analysis
- `GITHUB_PERMISSIONS_REQUIRED.md` - Complete permissions requirements
- `DEPLOYMENT_BLOCKER.md` - Kubernetes deployment blockers
- `BUILD_IMAGES.md` - Docker image build documentation

### Related Beads

- **mo-3ps** - This task: Grant GitHub push permissions to moltbook organization repositories
- **mo-3prx** (P0) - Blocker: Moltbook GitHub organization owner action required for push permissions
- **mo-1le** - Original admin action request for push permissions
- **mo-2xz2** - Docker build blocker caused by missing permissions (PRIORITY 0)
- **mo-2ik** - Original permission investigation and documentation

---

## 🆘 Troubleshooting

### Problem: Cannot find the moltbook organization

**Solution**: The organization may not exist or you may not have access. Verify with:
```bash
gh api orgs/moltbook
```

### Problem: User `jedarden` is already a member but still cannot push

**Solution**: Check repository-level permissions:
```bash
# Via UI: Go to repository Settings > Access
# Via CLI: Check specific permissions
gh api repos/moltbook/api/collaborators/jedarden --jq '.permissions'
```

### Problem: GitHub CLI command fails with 404

**Solution**: You may not have admin access to the repository. Use the GitHub Web UI instead.

---

## 📞 Contact

For questions or issues:
- Review `GITHUB_PERMISSIONS_BLOCKER.md` for detailed analysis
- Check `GITHUB_PERMISSIONS_REQUIRED.md` for complete requirements
- Contact the Moltbook team for deployment assistance

---

## 📝 Technical Details

### Repository URLs
- API: https://github.com/moltbook/api
- Frontend: https://github.com/moltbook/moltbook-frontend

### User Details
- GitHub username: `jedarden`
- Current token scopes: `delete_repo`, `gist`, `read:org`, `repo`, `workflow`
- Note: `admin:org` scope would be needed if jedarden were to grant permissions to themselves (not applicable - requires org owner)

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

## ✅ WORKAROUND IMPLEMENTED (mo-3ps)

Fork-based PRs have been created to unblock Docker image builds:
- **API PR**: https://github.com/moltbook/api/pull/103
- **Frontend PR**: https://github.com/moltbook/moltbook-frontend/pull/8

Once these PRs are merged by a moltbook organization maintainer, GitHub Actions will automatically build and push Docker images to ghcr.io.

## 🔴 LONG-TERM SOLUTION REQUIRED

For ongoing development, the moltbook organization owner should grant `jedarden` direct push permissions. See "Action Required" section above.

---

**Last Updated**: 2026-02-04
**Status**: 🟡 WORKAROUND IN PLACE - PRs created, awaiting review
**Priority**: P0 (Critical)
**Estimated Time**: 5 minutes (one-time setup)
**Related Bead**: mo-2uzu (Blocker: Grant GitHub push permissions)
