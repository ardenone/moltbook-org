# Filesystem Fix Summary - mo-9i6t

**Date:** 2026-02-05
**Bead ID:** mo-9i6t
**Status:** ✅ WORKAROUND IMPLEMENTED AND VERIFIED

## Summary

The Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has filesystem-level corruption that causes `npm install` to fail with `TAR_ENTRY_ERROR` and `ENOTEMPTY` errors. A functional workaround using `pnpm` with `/tmp` store and `tmpfs` mount for `node_modules` is in place and working correctly.

## Root Cause Analysis

### PVC Information
- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod`
- **StorageClass:** `longhorn`
- **Capacity:** 60Gi
- **Node:** `k3s-dell-micro`
- **Longhorn Status:** `robustness: healthy` (block device level)
- **Filesystem:** ext4 (corrupted at filesystem layer)

### Symptoms
1. `npm install` fails with `TAR_ENTRY_ERROR ENOENT` errors
2. Directories appear to be created but cannot be found during tar extraction
3. `rm -rf` fails with "Directory not empty" errors
4. File operations are inconsistent on the Longhorn PVC

### Why Longhorn Reports Healthy

The Longhorn volume shows `robustness: healthy` because the corruption is at the **ext4 filesystem layer**, not at the Longhorn block device layer. Longhorn manages block devices and replication, but does not monitor filesystem health.

## Implemented Workaround

### Solution: pnpm with /tmp Store + tmpfs node_modules

The workaround uses:
1. **pnpm** with `--store-dir /tmp/pnpm-store` to store package cache on overlay filesystem
2. **tmpfs** mount for `node_modules` directory (16GB, 2M inodes)

### Current Configuration

```bash
# node_modules is mounted on tmpfs
tmpfs on /home/coder/Research/moltbook-org/moltbook-frontend/node_modules \
  type tmpfs (rw,nosuid,nodev,relatime,size=16777216k,nr_inodes=2097152,inode64)

# .npmrc configuration
workspaces=false
legacy-peer-deps=true
```

### Verification Results

All tests pass with the workaround:

```bash
# pnpm install
✅ Works in ~1-2 seconds (764 packages)

# npm run build
✅ All routes compile successfully with Turbopack

# pnpm test
✅ 36 tests pass, 2 test suites pass
```

## Long-Term Solution

A follow-up bead has been created for the permanent fix:

**Bead ID:** mo-11sg
**Title:** Tech Debt: Recreate Longhorn PVC for coder-jeda-codespace
**Priority:** 3 (Backlog)

The permanent fix requires:
1. Backup any local data (everything important should be in git)
2. Delete devpod deployment
3. Delete the Longhorn PVC
4. Recreate devpod (will get fresh PVC)
5. Re-clone repositories and install dependencies

See `PVC_RECREATION_GUIDE.md` for detailed procedures.

## Files Created

1. `PVC_RECREATION_GUIDE.md` - Step-by-step guide for PVC recreation
2. `docs/PVC-MIGRATION-GUIDE.md` - Storage class migration options
3. `scripts/pvc-health-check.sh` - Diagnostic script for PVC health

## Related Issues

- **mo-1rp9** - Original npm install blocker (resolved with workaround)
- **mo-y72h** - Devpod filesystem corruption investigation
- **mo-11sg** - Tech debt for permanent PVC recreation

## References

- `BLOCKER_MO_1RP9_FILESYSTEM_SUMMARY.md` - Original analysis
- `NPM_INSTALL_BLOCKER_MO-1RP9.md` - Original blocker documentation
- `moltbook-frontend/scripts/pnpm-helper.sh` - pnpm helper script
