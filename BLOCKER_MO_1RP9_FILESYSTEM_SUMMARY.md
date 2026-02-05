# BLOCKER: Filesystem Corruption on Devpod Longhorn PVC

**Bead ID:** mo-1rp9
**Status:** BLOCKED - Requires PVC recreation or filesystem repair
**Created:** 2026-02-05

## Summary

The devpod's underlying Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has filesystem-level corruption causing `npm install` to fail repeatedly with `ENOENT` errors. The Longhorn volume shows `robustness: healthy` at the block device level, but the ext4 filesystem has corruption affecting file creation and deletion operations.

## Root Cause Analysis

### PVC Information
- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod` (ardenone-cluster)
- **StorageClass:** `longhorn`
- **Capacity:** 60Gi
- **Longhorn Volume:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Node:** `k3s-dell-micro`
- **Robustness:** `healthy` (block device level)

### Symptoms
1. **npm install failures** with repeated errors:
   - `TAR_ENTRY_ERROR ENOENT: no such file or directory`
   - `tarball data seems to be corrupted`
   - `ENOTEMPTY: directory not empty, rmdir`
   - `EEXIST: file already exists`

2. **Directory operations failing:**
   - Cannot remove directories: `Directory not empty`
   - Cannot create files: `ENOENT: no such file or directory`
   - Files disappear during operations

3. **Package managers affected:**
   - `npm install` - Fails with corrupted tarball errors
   - `pnpm install` - Fails with ENOENT during copy operations

4. **Localized to specific directories:**
   - `/home/coder/Research/moltbook-org/moltbook-frontend/node_modules` - **HEAVILY CORRUPTED**
   - `/home/coder/Research/moltbook-org/api/node_modules` - **WORKING**

### Test Results

#### Attempted Remediation Steps:
1. ✗ Remove `node_modules` - Failed: `Directory not empty` errors
2. ✗ `npm cache clean --force` - Completed but didn't help
3. ✗ Clean install with `npm install` - Failed with same errors
4. ✗ Try `pnpm install` - Failed with ENOENT during file copy

#### Successful Operations:
- API `npm test` runs successfully
- API `node_modules` directory appears healthy
- Longhorn volume reports healthy at block level
- Disk has 26GB free space (57% used)

## Impact

**BLOCKING:**
- Frontend development (`npm install`, `npm run build`)
- Frontend testing
- CI/CD pipelines that depend on frontend builds

**NOT BLOCKING:**
- API development and testing
- General filesystem operations
- Container operations

## Resolution Options

### Option 1: Recreate Devpod (Recommended - Fastest)
**Pros:**
- Quickest path to unblock development
- Fresh PVC with healthy filesystem
- Minimal manual intervention

**Steps:**
```bash
# 1. Backup critical data (already in git, but check for uncommitted work)
cd /home/coder/Research/moltbook-org && git status

# 2. Delete the devpod deployment
kubectl delete deployment coder-jeda-codespace -n devpod

# 3. Delete the PVC (WARNING: This deletes all data in /home/coder)
kubectl delete pvc coder-jeda-codespace-home -n devpod

# 4. Recreate devpod via devpod CLI or ArgoCD
# The new devpod will get a fresh PVC
```

**Cons:**
- Loses all local data in `/home/coder` (should be in git anyway)
- Requires re-setup of any local configurations

### Option 2: Filesystem Repair (More Complex)
**Pros:**
- Preserves existing data
- Fixes root cause

**Steps:**
```bash
# 1. Detach PVC from pod
kubectl delete pod coder-jeda-codespace-<pod-id> -n devpod

# 2. Create repair job that mounts PVC read-only initially
# 3. Run fsck on the volume
# 4. Reattach PVC
```

**Cons:**
- More complex
- May not fully repair corruption
- Requires pod downtime

### Option 3: Temporary Workaround (Use Different Directory)
**Pros:**
- Can unblock work immediately
- No data loss

**Steps:**
```bash
# Use /tmp or create project in /workspaces for frontend work
# But this doesn't fix the underlying issue
```

**Cons:**
- Doesn't fix root cause
- May hit same corruption elsewhere

## Related Beads

- **mo-2s69** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (created for tracking)

## Recommendation

**Proceed with Option 1: Recreate Devpod**

Given that:
1. All critical code is in git
2. The corruption is severe and widespread in node_modules
3. Development is fully blocked
4. Recreating devpod is a 5-10 minute operation

The fastest path to unblocking development is to recreate the devpod with a fresh PVC.

## Next Steps

1. Verify all work is committed to git
2. Coordinate with user for devpod recreation window
3. Delete and recreate devpod
4. Verify npm install works on new devpod
5. Close this bead as resolved
