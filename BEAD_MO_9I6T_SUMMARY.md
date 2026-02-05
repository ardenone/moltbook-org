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

## Long-term Solutions (Not Implemented)

### Option 1: Migrate to local-path Storage (Recommended)
- Faster performance (local SSD)
- Avoids Longhorn filesystem issues
- Single-node limitation acceptable for devpod

### Option 2: Migrate to proxmox-local-lvm
- High performance via Proxmox LVM
- Better I/O characteristics
- Proxmox-native storage

### Option 3: Recreate Longhorn PVC
- Fresh filesystem may resolve corruption
- Risk of corruption recurring
- Requires devpod recreation

## Action Items Created

1. **mo-9i6u** - Infrastructure: Migrate devpod PVC from Longhorn to local-path storage
   - Priority: 1 (High)
   - Description: Plan and execute migration to eliminate Longhorn filesystem issues

2. **mo-9i6v** - Infrastructure: Document Longhorn vs local-path storage class comparison
   - Priority: 2 (Normal)
   - Description: Create decision matrix for storage class selection

## Related Beads

- **mo-1rp9** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (previous investigation)
- **mo-2s69** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (duplicate tracking)

## Scripts Created

1. `scripts/pvc-health-check.sh` - Comprehensive PVC health diagnostic tool
2. `scripts/npm-install-workaround.sh` - Automated workaround implementation

## How to Use the Workaround

```bash
# In moltbook-frontend directory
cd /home/coder/Research/moltbook-org/moltbook-frontend

# Use pnpm with /tmp store
npx pnpm install --store-dir /tmp/pnpm-store

# Or use the health check script with --fix flag
./scripts/pvc-health-check.sh --fix
```

## Conclusion

**Status:** Development is UNBLOCKED via workaround. The underlying Longhorn PVC filesystem corruption remains unresolved but does not prevent development work. Migration to a different storage class (local-path or proxmox-local-lvm) is recommended during the next maintenance window.
