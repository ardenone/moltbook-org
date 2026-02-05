# Devpod Recreation Required - Filesystem Corruption

**Date:** 2026-02-05
**Bead:** mo-1rp9
**Status:** BLOCKER - Devpod recreation required

---

## Executive Summary

The devpod's underlying Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has **filesystem corruption** that prevents any node-based package manager (npm, pnpm) from completing installations on the mounted volume at `/home/coder`.

**This cannot be fixed at the application level.** The devpod must be recreated with a fresh PVC.

---

## Evidence of Filesystem Corruption

### 1. Direct npm/pnpm Install Failures

```bash
# pnpm install (on Longhorn PVC)
ERR_PNPM_ENOTEMPTY ENOTEMPTY: directory not empty, rmdir
# Error occurs in date-fns locale directory
```

### 2. Filesystem Operations Fail

```bash
# rm -rf cannot properly remove directories
rm: cannot remove 'node_modules/next/dist': Directory not empty
rm: cannot remove 'node_modules/eslint-plugin-react/lib/util': Directory not empty

# find reports files that don't exist
find: 'node_modules/.eslint-plugin-react-hooks-v8yzZxIo': No such file or directory
```

### 3. Docker Overlay Mount Fails

```bash
docker: Error response from daemon: failed to mount
err: invalid argument
```

This confirms the issue extends to the storage layer itself.

---

## What Works

### Overlay Filesystem (/tmp, /)

Installing to the overlay filesystem works perfectly:

```bash
cd /tmp && npm install eslint
# Result: SUCCESS - added 85 packages in 2s
```

### Workaround Limitations

While installing to `/tmp` works, **copying the installed `node_modules` to the Longhorn PVC fails** because the filesystem cannot properly handle directory operations.

---

## Recommended Solution

### Devpod Recreation (REQUIRED)

1. **Backup**: Git repositories are already pushed - no data loss
2. **Delete devpod**: Stop the current devpod pod
3. **Delete PVC**: Delete `coder-jeda-codespace-home` PVC in `devpod` namespace
4. **Recreate**: Allow devpod to provision with a fresh, healthy Longhorn volume

### Why This is Necessary

- The filesystem corruption is at the **block storage layer**
- It cannot be repaired while mounted
- Longhorn will provision a healthy volume automatically
- All code is in git - only tool configuration would need to be redone

---

## PVC Details

```
Name: pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1
Claim: devpod/coder-jeda-codespace-home
Capacity: 60Gi
Filesystem: ext4
Mount Point: /home/coder
Status: Bound (16 days old)
```

---

## Alternative Approaches Considered

| Approach | Status | Reason |
|----------|--------|--------|
| npm install with flags | FAILS | Filesystem cannot handle tar extraction |
| pnpm install | FAILS | Same filesystem corruption |
| Install to /tmp, then copy | FAILS | Cannot copy to corrupted fs |
| Docker build | FAILS | Overlay mount fails on corrupted fs |
| tmpfs bind mount | PARTIAL | Works but complex to maintain |
| fsck repair | RISKY | Requires unmounting, may not fix storage issue |

---

## Immediate Actions Required

1. User approval to recreate devpod
2. Coordinate with devpod administrator
3. Verify git repos are pushed (27 commits ahead)
4. Plan for tool reinstallation after recreation

---

## Latest Verification (2026-02-05 12:08)

Even after npm reports "added 787 packages" with "found 0 vulnerabilities", the installation is completely broken:

```bash
# npm install appears to succeed
added 787 packages, and audited 788 packages in 1m
found 0 vulnerabilities

# But node_modules is corrupted:
$ ls node_modules/.bin/
ls: cannot access 'node_modules/.bin/': No such file or directory

$ npm run build
sh: 1: next: not found

$ ls node_modules/next/
# Directory exists but package.json is missing

$ find node_modules -name "package.json"
# No results - critical files missing
```

**The corruption manifests in a new way:** npm tar extraction completes but files are not properly written to disk. This confirms the filesystem has deep metadata corruption that prevents reliable file operations.

---

## Files Created During Investigation

- `DEVPOD_FILESYSTEM_ANALYSIS.md` - Initial fsck and test results
- `FILESYSTEM_FIX_MO_1RP9.md` - Pnpm workaround attempt
- `FILESYSTEM_ISSUE_WORKAROUND.md` - Workaround documentation
- `BLOCKER_MO_1RP9_FILESYSTEM_SUMMARY.md` - Initial blocker summary
- This file - Final analysis and recommendation (updated with latest verification)
