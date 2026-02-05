# Devpod Filesystem Analysis - ENOENT Errors During npm install

**Date:** 2026-02-05
**Bead:** mo-1rp9
**PVC:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
**Mount Point:** `/home/coder`

---

## Problem Summary

The devpod's underlying Longhorn PVC (`coder-jeda-codespace-home`) is experiencing filesystem corruption that causes `npm install` to fail repeatedly with ENOENT errors when creating directories in `node_modules`. This is blocking frontend development and builds for the Moltbook project.

---

## Investigation Results

### 1. PVC Status
- **Status:** Bound and appears healthy from Kubernetes perspective
- **Storage Class:** longhorn
- **Capacity:** 60Gi
- **Used:** 34G / 59G (57%)
- **Filesystem:** ext4
- **Age:** 16 days

### 2. Filesystem Check Results
```bash
sudo fsck -n /dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1
# Result: clean, 710849/3932160 files, 8460619/15728640 blocks
```

The filesystem check shows "clean" but this is a read-only check on a mounted filesystem. Many corruption issues only appear under write load.

### 3. Test Results

#### ✅ /tmp Filesystem (overlay - different device)
```bash
cd /tmp && npm install eslint
# Result: SUCCESS - added 85 packages in 2s
```

#### ❌ /home/coder Filesystem (Longhorn PVC)
```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend && npm install
# Result: FAILURE - Thousands of ENOENT errors
```

**Sample errors:**
- `ENOENT: no such file or directory, open 'node_modules/baseline-browser-mapping/dist/index.cjs'`
- `TAR_ENTRY_ERROR ENOENT: no such file or directory, lstat 'node_modules/next/dist'`
- `ENOTEMPTY: directory not empty, rmdir 'node_modules/@typescript-eslint/type-utils/dist'`

### 4. Key Observations

1. **Device-Specific Issue:** The problem is isolated to the Longhorn PVC at `/home/coder`. Other filesystems (`/tmp` overlay) work fine.

2. **Inode/Table Corruption:** The fsck shows the filesystem appears clean, but the pattern of errors suggests:
   - Inode allocation issues
   - Directory entry corruption
   - Possible journaling problems

3. **Partial Install:** The npm install creates many files but fails to access them immediately after creation, indicating the filesystem metadata is inconsistent.

---

## Root Cause Analysis

The most likely causes for this behavior:

1. **Longhorn Volume Degradation:** The underlying Longhorn replica may have issues with:
   - Network attachment corruption
   - Replica synchronization issues
   - Block-level storage problems

2. **ext4 Journal Issues:** The filesystem journal may have unflushed transactions causing metadata inconsistency.

3. **PVC Overprovisioning:** The host node may be overcommitted on I/O resources.

---

## Recommended Solution

### Option 1: Recreate Devpod (RECOMMENDED)

This is the fastest and most reliable solution:

1. **Backup current data:** Copy any uncommitted work to a safe location
2. **Delete the devpod:** This will delete the pod but the PVC will persist
3. **Delete the PVC:** Delete `coder-jeda-codespace-home` PVC to force Longhorn to create a fresh volume
4. **Recreate devpod:** Allow a fresh PVC with clean filesystem to be provisioned

**Pros:**
- Guaranteed clean filesystem
- Faster than attempting repair
- Longhorn will automatically provision healthy storage

**Cons:**
- Requires re-cloning git repositories
- Requires re-installing any tools not persisted externally
- Data on PVC will be lost (but git repos can be re-cloned)

### Option 2: Attempt Filesystem Repair (RISKY)

Try to repair the filesystem in-place:

```bash
# 1. Shutdown the devpod (unmounts the PVC)
# 2. Run fsck on the unmounted volume
# 3. Restart devpod
```

**Pros:**
- May preserve data

**Cons:**
- Devpod must be stopped to perform repair
- Repair may fail or cause further data loss
- Underlying Longhorn issue may persist

---

## Conclusion

The filesystem on the Longhorn PVC is corrupted in a way that causes npm operations to fail. The recommended fix is to recreate the devpod with a fresh PVC. This is a storage-layer issue that cannot be worked around at the application level.

**Immediate Action Required:** Create a blocker bead to coordinate devpod recreation with the user.
