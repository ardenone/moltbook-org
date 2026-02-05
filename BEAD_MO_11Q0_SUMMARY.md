# BEAD MO-11Q0 SUMMARY: Longhorn Storage Filesystem Investigation

**Bead ID:** mo-11q0
**Title:** Blocker: Longhorn storage filesystem corruption preventing npm install
**Date:** 2026-02-05
**Status:** ✅ VERIFIED - Workaround remains functional

## Summary

This bead investigated the reported Longhorn PVC filesystem corruption causing ENOTEMPTY errors during npm install. The investigation confirmed that:
1. The original issue (documented in beads mo-1rp9, mo-9i6t) was resolved with a tmpfs workaround
2. The workaround remains fully functional and operational
3. Basic npm install operations on the PVC now work correctly for simple packages
4. The ext4 filesystem shows as "clean" in read-only fsck

## Investigation Results

### PVC Information
- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod` (ardenone-cluster)
- **StorageClass:** `longhorn`
- **Capacity:** 60Gi (27G free / 33G used)
- **Mount Point:** `/home/coder` (ext4)
- **Node:** `k3s-dell-micro`

### Filesystem Health Check

```bash
# Read-only fsck on mounted volume
sudo fsck.ext4 -n /dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1
# Result: clean, 715367/3932160 files, 8938488/15728640 blocks
```

The filesystem reports as **clean** with no detected corruption at the ext4 layer.

### Test Results

#### Test 1: npm install on /tmp (overlay filesystem)
```bash
cd /tmp/npm-test-longhorn
npm install lodash
# Result: ✅ Success - 369ms
```

#### Test 2: npm install on Longhorn PVC
```bash
cd ~/Research/moltbook-org/test-npm-on-pvc
npm install lodash
# Result: ✅ Success - 666ms
```

Both tests passed successfully. The ENOTEMPTY errors previously encountered may have been specific to:
1. The corrupted `node_modules` directory structure (now bypassed with tmpfs)
2. Large-scale package installations (764 packages vs single package test)
3. Specific package tar extraction patterns

## Current Workaround Status

### Active Workaround: tmpfs for node_modules

The workaround implemented in bead mo-9i6t remains active and functional:

```bash
# node_modules is mounted on tmpfs
tmpfs on /home/coder/Research/moltbook-org/moltbook-frontend/node_modules \
  type tmpfs (rw,nosuid,nodev,relatime,size=16777216k,nr_inodes=2097152,inode64)
```

### Configuration
- **Package Manager:** pnpm with `--store-dir /tmp/pnpm-store`
- **node_modules Location:** tmpfs (16GB, 2M inodes)
- **npmrc Settings:**
  ```
  workspaces=false
  legacy-peer-deps=true
  ```

### Verification
- ✅ node_modules contains 764 packages via pnpm symlinks
- ✅ All dependencies are accessible
- ✅ Build process works with Turbopack configuration

## Kernel Logs Analysis

Reviewed dmesg logs for filesystem errors. Found only overlay filesystem warnings (related to Docker/Containerd), no ext4 or Longhorn errors:

```
overlay: filesystem on /var/lib/docker/... not supported as upperdir
```

These are Docker containerd snapshotter issues, not related to the Longhorn PVC.

## Historical Context

### Previous Issues (Resolved via Workaround)
1. **Bead mo-1rp9:** Original npm install blocker with ENOTEMPTY errors
2. **Bead mo-9i6t:** Implementation of tmpfs + pnpm workaround
3. **Bead mo-11sg:** Tech debt for permanent PVC recreation (Priority 3: Backlog)

### Root Cause (Historical)
The original issue was caused by ext4 filesystem corruption on the Longhorn PVC that:
- Prevented tar extraction during npm install
- Caused "Directory not empty" errors during removal
- Made file operations unreliable

## Long-Term Recommendation

While the workaround is functional, the Longhorn PVC should still be recreated during a maintenance window to:
1. Eliminate reliance on the tmpfs workaround
2. Restore normal filesystem operations
3. Prevent potential future issues

See `PVC_RECREATION_GUIDE.md` for detailed procedures.

## Related Files

- `BLOCKER_MO_1RP9_FILESYSTEM_SUMMARY.md` - Original blocker analysis
- `NPM_INSTALL_BLOCKER_MO-1RP9.md` - Original npm install blocker documentation
- `FILESYSTEM_FIX_SUMMARY_MO_9I6T.md` - Workaround implementation details
- `PVC_RECREATION_GUIDE.md` - Permanent fix procedures

## Conclusion

**STATUS:** The reported issue is already resolved with a functional workaround. The filesystem check shows the PVC is clean. Basic npm operations work correctly. The tmpfs workaround for node_modules continues to provide reliable development operations.

**NO IMMEDIATE ACTION REQUIRED** - The system is working as intended with the workaround in place.
