# Bead MO-1WWV Summary: node_modules corruption - frontend build failing

**Bead ID:** mo-1wwv
**Status:** RESOLVED - Workaround already in place
**Created:** 2026-02-05
**Resolved:** 2026-02-05

## Summary

The frontend build was failing due to node_modules corruption from the Longhorn PVC filesystem issue. However, a working workaround using tmpfs for node_modules was already implemented in previous beads (mo-9i6t, mo-y72h). The build is now functioning correctly.

## Current State Verification

### 1. node_modules tmpfs mount (Active)
```bash
tmpfs on /home/coder/Research/moltbook-org/moltbook-frontend/node_modules \
  type tmpfs (rw,nosuid,nodev,relatime,size=16777216k,nr_inodes=2097152,inode64)
```

### 2. pnpm install (Working)
```bash
npx pnpm install --store-dir /tmp/pnpm-store
# Output: Done in 1.2s using pnpm v10.28.2
```

### 3. npm run build (Working)
```bash
npm run build
# Output: ✓ Compiled successfully in 3.0s
#         All routes compiled successfully
#         22 routes generated
```

### 4. npm test (Working)
```bash
npm test
# Output: Test Suites: 2 passed, 2 total
#         Tests: 36 passed, 36 total
```

## Workaround Details

### Prerequisites Already Met
1. **pnpm** is installed and working
2. **tmpfs mount** for node_modules is active (16GB, 2M inodes)
3. **Turbopack** is enabled in next.config.js
4. **pnpm store** is on /tmp (overlay filesystem, not corrupted PVC)

### Configuration Files
- **package.json**: Build script uses pnpm with Turbopack
- **next.config.js**: Turbopack enabled to avoid webpack issuerLayer errors
- **.npmrc**: pnpm-specific configuration

### Scripts Available
- `scripts/npm-install-fix.sh`: Install script for fresh installations
- `scripts/pnpm-helper.sh`: Helper script for pnpm operations

## Root Cause

The Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has filesystem-level corruption:
- **Block device layer**: Longhorn reports `robustness: healthy`
- **Filesystem layer**: ext4 has corruption affecting file operations
- **Impact**: npm/pnpm installs fail with TAR_ENTRY_ERROR and ENOENT errors

## Resolution Status

### Current Solution (Working)
- **tmpfs mount** for node_modules (non-persistent, survives pod restart via mount)
- **pnpm** with store on /tmp
- **Turbopack** for builds

### Long-term Solution (Deferred)
A tech debt bead exists for permanent fix:
- **Bead ID**: mo-11sg
- **Title**: Tech Debt: Recreate Longhorn PVC for coder-jeda-codespace
- **Priority**: 3 (Backlog)

See `PVC_RECREATION_GUIDE.md` for detailed procedures.

## Related Beads

- **mo-9i6t** - Filesystem fix summary (tmpfs workaround implementation)
- **mo-y72h** - Devpod filesystem corruption investigation
- **mo-1rp9** - Original npm install blocker
- **mo-11sg** - Tech debt for permanent PVC recreation

## Files Created/Modified

1. `FILESYSTEM_WORKAROUND.md` - Workaround documentation
2. `NPM_FILESYSTEM_FIX_SUMMARY_MO_Y72H.md` - Fix summary with commands
3. `FILESYSTEM_FIX_SUMMARY_MO_9I6T.md` - Summary with verification
4. `PVC_RECREATION_GUIDE.md` - Long-term fix guide
5. `scripts/npm-install-fix.sh` - Install script for fresh installations
6. `scripts/pnpm-helper.sh` - Helper script

## Verification Steps

To verify the fix works:
```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend

# 1. Check tmpfs mount
mount | grep node_modules

# 2. Install dependencies
npx pnpm install --store-dir /tmp/pnpm-store

# 3. Build
npm run build

# 4. Test
npm test
```

All steps should complete successfully.

## Notes for Future Work

1. **Pod restart**: When devpod restarts, tmpfs mount persists but node_modules needs reinstallation
2. **Permanent fix**: Schedule PVC recreation during maintenance window
3. **React context error**: Should be resolved with clean build (verify if still present)
