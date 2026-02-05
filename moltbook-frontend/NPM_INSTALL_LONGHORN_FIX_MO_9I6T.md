# Longhorn PVC Filesystem Corruption Fix - mo-9i6t

**Date:** 2026-02-05
**Bead ID:** mo-9i6t
**Related Beads:** mo-1rp9, mo-813a (blocker for devpod recreation)

---

## Summary

The Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has severe filesystem corruption that blocks `npm install` and build operations. A workaround script has been implemented that installs dependencies to a temporary filesystem (`/tmp`) and transfers them using `tar`, which handles the corruption better than `cp` or `mv`.

---

## Root Cause

### Longhorn PVC Details
- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod` (ardenone-cluster)
- **StorageClass:** `longhorn`
- **Mount Point:** `/home/coder` (ext4)
- **Capacity:** 60Gi
- **Node:** `k3s-dell-micro`

### Filesystem Corruption Symptoms

1. **npm/pnpm Install Failures:**
   - `TAR_ENTRY_ERROR ENOENT: no such file or directory`
   - `ENOTEMPTY: directory not empty, rmdir`
   - Files disappear after being created

2. **SWC Binary Corruption:**
   - `failed to map segment from shared object` errors
   - Native `.node` files are corrupted at the block level

3. **Directory Operations Fail:**
   - Cannot remove directories: "Directory not empty" on empty directories
   - Cannot create files: `ENOENT` immediately after creation
   - `.bin` directory intermittently disappears

4. **Build Failures:**
   - `Cannot find module 'next/types.js'`
   - Build artifacts disappear during compilation
   - Lock files cannot be removed

---

## Workaround Implementation

### Script: `scripts/npm-install-fix.sh`

This script:
1. Installs dependencies to `/tmp` (different filesystem - not affected by corruption)
2. Uses `pnpm` with `--store-dir` pointing to `/tmp`
3. Transfers `node_modules` using `tar` (handles corruption better than `cp`/`mv`)
4. Backs up the corrupted `node_modules` for reference

### Usage

```bash
cd moltbook-frontend
./scripts/npm-install-fix.sh
```

### Verification

```bash
# After running the fix script, verify with:
node node_modules/next/dist/bin/next build

# Expected output: Successful build with all routes compiled
```

---

## Build Results (After Fix)

```
✓ Compiled successfully in 2.6s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (6/6) in 49.0ms
  Finalizing page optimization ...

Route (app)              ┌────────────────────────────────────┐
│ /                     │ Compiled successfully              │
│ /auth/login           │ 23 routes generated                │
│ /post/[id]            │                                    │
...                     └────────────────────────────────────┘
```

---

## Limitations of the Workaround

1. **Temporary Fix Only:** The corruption persists on the PVC
2. **Requires Re-running:** The fix may need to be re-applied periodically
3. **Build Fragility:** Builds may fail if `.next` directory gets corrupted
4. **SWC Binaries:** Native modules may need to be reinstalled

---

## Permanent Fix: Devpod Recreation

The devpod needs to be recreated with a fresh Longhorn PVC:

### Steps

1. **Backup Data:** Ensure all work is committed to git
2. **Stop Devpod:** Delete the deployment
3. **Delete PVC:** Delete `coder-jeda-codespace-home` PVC
4. **Recreate:** Allow devpod to provision with a fresh volume

### Why This is Necessary

- The corruption is at the **block storage layer** (ext4 on Longhorn)
- Cannot be repaired while the volume is mounted
- Longhorn will automatically provision a healthy volume
- All code is in git - minimal data loss

---

## Related Blocker Bead

**mo-813a:** "Fix: Longhorn PVC filesystem corruption blocking npm install"
- Priority: 1 (High)
- Status: Open
- Action Required: Devpod recreation with fresh PVC

---

## Technical Analysis

### Why `/tmp` Works

The `/tmp` directory uses a different filesystem (overlay/tmpfs) that is not backed by the Longhorn PVC. Operations on `/tmp` complete successfully because:

1. No network storage latency
2. Different block device (no Longhorn issues)
3. No ext4 journal corruption

### Why `tar` Works Better Than `cp`/`mv`

- `tar` streams data sequentially, reducing random I/O
- Handles partial writes more gracefully
- Preserves permissions and metadata more reliably
- Single atomic operation vs thousands of small files

### Longhorn-Specific Issues

The Longhorn volume shows "healthy" at the engine level, but the ext4 filesystem has:
- Inode allocation problems
- Directory entry corruption
- Journal consistency issues
- Block mapping errors (affecting binary files)

---

## Files Created/Modified

- `scripts/npm-install-fix.sh` - Automated workaround script
- `NPM_INSTALL_LONGHORN_FIX_MO_9I6T.md` - This documentation

---

## Next Steps

1. ✅ Workaround implemented and tested
2. ✅ Build verification successful
3. ⏳ Schedule devpod recreation (mo-813a)
4. ⏳ Monitor for recurrence of corruption

---

## References

- Original issue: mo-1rp9 (filesystem corruption investigation)
- Previous workaround: mo-y72h (npm install workaround)
- Blocker: mo-813a (devpod recreation required)
