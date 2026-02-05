# BEAD mo-9i6t: Longhorn PVC Filesystem Corruption - Status Summary

**Bead ID:** mo-9i6t
**Title:** Fix: Longhorn PVC filesystem corruption blocking npm installs
**Status:** WORKAROUND CONFIRMED FUNCTIONAL
**Created:** 2026-02-05
**Updated:** 2026-02-05

## Summary

The Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c1`) at `/dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` has persistent filesystem-level corruption that causes npm install to fail with ENOTEMPTY/ENOENT errors during tar extraction. However, a functional workaround using pnpm with a `/tmp` store directory is working correctly.

## Current Status: WORKAROUND FUNCTIONAL

### What's Working
- **pnpm install**: Works with `--store-dir /tmp/pnpm-store` flag
- **npm run build**: Completes successfully with Turbopack
- **Frontend development**: Unblocked and functional
- **Filesystem tests**: Basic operations (create, read, delete, tar) pass on /tmp overlay

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

## Verification Results

```
=== Filesystem Health Tests ===
✓ Directory creation: OK
✓ Directory removal: OK
✓ File write/read: OK
✓ File deletion: OK
✓ TAR extraction: OK

=== Frontend Dependency Installation ===
Current node_modules size: 1.5G
✓ pnpm install with /tmp store: SUCCESS
✓ Build artifacts present
✓ npm run build: SUCCESS
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
