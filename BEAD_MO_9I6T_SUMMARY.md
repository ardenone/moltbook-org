# BEAD MO-9I6T: Longhorn PVC Filesystem Corruption - Final Analysis

**Bead ID:** mo-9i6t
**Title:** Fix: Longhorn PVC filesystem corruption blocking npm installs
**Status:** ANALYSIS COMPLETE - DEVPOD RECREATION RECOMMENDED
**Created:** 2026-02-05
**Updated:** 2026-02-05

## Summary

The Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) at `/dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` has **severe filesystem-level corruption** that has worsened beyond the point where workarounds are viable. Previous workarounds using `/tmp` store directories are no longer effective for transferring `node_modules` to the PVC.

## Current Status: WORKAROUNDS DEGRADED - RECREATION RECOMMENDED

### What's Broken
- **pnpm install**: Reports success but installs incomplete packages (60MB instead of 2GB)
- **node_modules transfer**: tar and rsync transfers fail silently
- **Frontend build**: Cannot run - Next.js binary not found
- **File operations**: Large-scale operations fail, single files work

### What Still Works
- **Single file operations**: echo, touch, rm on individual files
- **Git operations**: commit, push, pull work normally
- **API development**: Less affected than frontend

### PVC Health Details
- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod` (ardenone-cluster)
- **StorageClass:** `longhorn`
- **Capacity:** 60Gi
- **Usage:** 33G used / 26G available (57%)
- **Mount Point:** `/home/coder`
- **Filesystem:** ext4
- **Longhorn Volume Status:** "healthy" at block level, but ext4 filesystem has corruption

## Root Cause Analysis

### Why the Workaround Works

The workaround is effective because `/tmp` is on a **different filesystem** (overlay tmpfs) than the Longhorn PVC:

```bash
# Longhorn PVC (corrupted ext4)
/home/coder → /dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1

# /tmp overlay (healthy, different filesystem)
/tmp → overlay (tmpfs/overlayfs)
```

When pnpm runs with `--store-dir /tmp/pnpm-store`:
1. Package download and extraction happens on `/tmp` (healthy filesystem)
2. Only final package installation touches the PVC
3. Symlinks in node_modules point to `.pnpm/` directory on PVC

### Why npm Fails on Longhorn PVC

1. **npm's tar extraction** creates directories then immediately tries to stat them
2. **Longhorn ext4 filesystem** has corruption where directory entries become inconsistent
3. **Result:** ENOENT/ENOTEMPTY errors during extraction

## Verification Results (2026-02-05 12:35 UTC)

```
=== Filesystem Health Tests ===
✓ Single file write/read: OK
✗ Large-scale transfers: FAIL (tar, rsync)
✗ npm/pnpm install: FAIL (incomplete installation)
✗ node_modules transfer: FAIL (silent failures)

=== Frontend Dependency Installation ===
✗ pnpm install: Reports success, but node_modules incomplete (60MB vs 2GB expected)
✗ tar transfer from /tmp: Silent failure, incomplete node_modules
✗ rsync transfer: Only 1052 files transferred (thousands expected)
✗ Build: Cannot run - Next.js binary not found
```

## Available Storage Classes

| Storage Class | Provisioner | Characteristics |
|--------------|-------------|-----------------|
| `longhorn` | driver.longhorn.io | **Current** - Distributed, has corruption issues |
| `local-path` | rancher.io/local-path | Local SSD, faster, single-node |
| `nfs-synology` | synology-nfs | Network storage, shared across nodes |
| `proxmox-local-lvm` | csi.proxmox.sinextra.dev | Proxmox LVM, high performance |

## Recommended Solution: Devpod Recreation (REQUIRED)

### Why This Is Necessary

1. **Filesystem corruption is irreversible** without offline fsck
2. **Workarounds have degraded** - previous methods no longer work
3. **PVC is only 16 days old** - minimal data to lose
4. **All code is in git** - can be re-cloned
5. **Longhorn volume healthy at block level** - new PVC will be fine

### Steps to Recreate Devpod

```bash
# 1. Ensure all work is committed to git
cd /home/coder/Research/moltbook-org
git status
git add .
git commit -m "WIP: Saving state before devpod recreation"

# 2. Delete the devpod deployment (stops the pod)
kubectl delete deployment coder-jeda-codespace -n devpod

# 3. Delete the PVC (WARNING: Deletes ALL data in /home/coder)
kubectl delete pvc coder-jeda-codespace-home -n devpod

# 4. Recreate devpod via devpod CLI or ArgoCD
# The new devpod will get a fresh PVC with clean filesystem
```

### What Will Be Lost
- Local node_modules (can be reinstalled)
- Any local config files not in git
- Any uncommitted work
- Build artifacts (.next, dist, etc.)

### What Will Be Preserved
- All git repos (can be re-cloned)
- Remote configurations
- Container images
- External services

## Long-term Solutions (After Recreation)

### Option 1: Use local-path Storage for New Devpod (Recommended)
- Faster performance (local SSD)
- Avoids Longhorn filesystem issues
- Single-node limitation acceptable for devpod

### Option 2: Stay on Longhorn with Monitoring
- Fresh PVC should work fine
- Add Longhorn volume monitoring
- Set up alerts for volume degradation

## Related Beads

- **mo-1rp9** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (previous investigation)
- **mo-2s69** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (duplicate tracking)

## Scripts Created

1. `scripts/pvc-health-check.sh` - Comprehensive PVC health diagnostic tool
2. `scripts/npm-install-workaround.sh` - Automated workaround implementation (NO LONGER EFFECTIVE)

## Comparison: Previous vs Current Status

### Previous Status (BLOCKER_MO_1RP9, Earlier 2026-02-05)
- Workaround using `/tmp` + tar transfer was **SUCCESSFUL**
- node_modules: 2.2GB, 764 packages
- Build: Working with Turbopack
- Method: `pnpm install --store-dir /tmp/pnpm-store` + tar transfer

### Current Status (MO-9I6T, 2026-02-05 12:35)
- **Same workaround now FAILS**
- node_modules: 60MB (incomplete)
- Build: Cannot run - Next.js binary not found
- Corruption has **worsened** significantly

## Conclusion

**Status:** Development is **BLOCKED**. The Longhorn PVC filesystem corruption has worsened beyond the point where workarounds are viable. Devpod recreation with a fresh PVC is the **only guaranteed solution** to restore normal operations.

**Next Steps:**
1. **User approval required** for devpod recreation
2. Backup any critical uncommitted data
3. Execute devpod recreation procedure
4. Verify npm install works on new PVC
5. Consider using local-path storage class for new devpod

---

## Analysis Completed

**Date:** 2026-02-05
**Analysis Duration:** ~15 minutes
**Methods Attempted:** 4 (direct install, tar transfer, rsync, shamefully-hoist)
**All Methods:** Failed due to filesystem corruption
**Recommendation:** Devpod recreation with fresh PVC
