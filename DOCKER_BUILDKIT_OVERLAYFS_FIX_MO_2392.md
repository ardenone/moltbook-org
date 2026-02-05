# Docker BuildKit Overlayfs Fix - Analysis and Resolution

**Bead ID:** mo-2392
**Date:** 2026-02-05
**Status:** ✅ RESOLVED - Docker builds now working with PVC storage

## Problem Statement

Docker BuildKit was failing with overlayfs mount error "invalid argument" when attempting to build container images on the devpod.

### Error Details (Historical)

```
ERROR: process "/bin/sh -c echo \"test\" > /tmp/test.txt" did not complete successfully:
mount source: "overlay", target: "/var/lib/docker/buildkit/containerd-overlayfs/cachemounts/buildkit693909555",
fstype: overlay, flags: 0,
data: "workdir=/var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.overlayfs/snapshots/288/work,
upperdir=/var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.overlayfs/snapshots/288/fs,
lowerdir=/var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.overlayfs/snapshots/287/fs,
index=off,redirect_dir=off",
err: invalid argument
```

## Root Cause Analysis

### Issue 1: Nested Overlayfs in Devpod Environment

The devpod itself runs inside an overlayfs filesystem with 26 layers:

```
overlay on / type overlay (rw,relatime,
  lowerdir=/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/630/fs:
          /var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/629/fs:
          [... 26 total layers ...]
          /var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/605/fs,
  upperdir=/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2975/fs,
  workdir=/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2975/work,
  uuid=on)
```

Docker BuildKit attempted to create **nested overlayfs mounts** on top of this existing overlayfs layer, which the kernel rejected with "invalid argument".

### Architecture (Before Fix)

```
┌─────────────────────────────────────────────────────────────┐
│ Node Filesystem (ext4 on nvme0n1p2)                        │
├─────────────────────────────────────────────────────────────┤
│ K3s containerd overlayfs (26 layers) ← Running pod root    │
├─────────────────────────────────────────────────────────────┤
│ /var/lib/docker (on overlayfs)                             │
├─────────────────────────────────────────────────────────────┤
│ Docker BuildKit overlayfs ← FAILED HERE (nested overlayfs) │
└─────────────────────────────────────────────────────────────┘
```

### Kernel Configuration

- **Kernel Version:** 6.12.63+deb13-amd64
- **Page Size:** 4096 bytes
- **Overlayfs module:** Loaded (217088 references)
- **Max user namespaces:** 255328

### Why It Failed

The kernel has limits on overlayfs nesting. When Docker BuildKit (running inside an overlayfs) tried to create another overlayfs mount for container build operations, it exceeded these limits or hit incompatibility issues with the nested configuration.

## Resolution

### Solution: Relocate Docker Data Directory to PVC

**Implemented in commit:** `66fdf9a` (feat(mo-2392): Fix: Devpod storage layer - Docker overlayfs nested mount issue)

The issue was resolved by moving Docker's data directory from `/var/lib/docker` (on overlayfs) to `/home/coder/.docker-data` (on the Longhorn PVC with ext4 filesystem).

### Changes Made

1. **Created new Docker storage location:**
   ```bash
   mkdir -p /home/coder/.docker-data
   ```

2. **Configured Docker daemon:**
   - Docker Root Dir: `/home/coder/.docker-data` (was: `/var/lib/docker`)
   - Storage Driver: overlay2 (was: overlayfs with nesting)

3. **Configuration file:** `/etc/default/docker` with `DOCKER_OPTS`

### Architecture (After Fix)

```
┌─────────────────────────────────────────────────────────────┐
│ Node Filesystem (ext4 on nvme0n1p2)                        │
├─────────────────────────────────────────────────────────────┤
│ K3s containerd overlayfs (26 layers) ← Running pod root    │
├─────────────────────────────────────────────────────────────┤
│ /home/coder (Longhorn PVC with ext4)                       │
├─────────────────────────────────────────────────────────────┤
│ /home/coder/.docker-data (ext4) ← Docker storage here      │
├─────────────────────────────────────────────────────────────┤
│ Docker BuildKit overlayfs ← NOW WORKS (on ext4, not nested)│
└─────────────────────────────────────────────────────────────┘
```

## Verification

### Current Docker Configuration

```bash
$ docker info | grep "Docker Root Dir"
 Docker Root Dir: /home/coder/.docker-data
```

### Test Results (2026-02-05)

```bash
$ docker buildx build -f /tmp/Dockerfile.test -t test-build-final /tmp
#0 building with "default" instance using docker driver
#1 [internal] load build definition from Dockerfile.test
#1 DONE 0.1s
#4 [1/2] FROM docker.io/library/alpine:3.19
#4 DONE 0.1s
#5 [2/2] RUN echo "test" > /tmp/test.txt
#5 DONE 0.7s
#6 exporting to image
#6 DONE 1.2s
```

**Result:** ✅ PASSED - Docker builds now work correctly

## Alternative Workarounds (Not Required After Fix)

These were investigated but are no longer needed since the issue is resolved:

### Workaround 1: Buildah (LIMITED - User Namespace Issues)

**Status:** ❌ NOT WORKING - Buildah fails with user namespace errors in devpod

Buildah is installed but encounters user namespace issues:

```bash
buildah bud -f Dockerfile -t myimage:latest .
# Error: insufficient UIDs or GIDs available in user namespace
# lchown /etc/shadow: invalid argument
```

**Why Buildah Fails:**
- Devpod runs in a restricted user namespace
- Buildah's rootless mode requires `/etc/subuid` and `/etc/subgid` mappings
- The kernel rejects `lchown` operations for certain UIDs/GIDs when extracting container images

**Container Tools Status:**
- ✅ `buildah` installed (v1.33.7)
- ❌ User namespace mappings fail
- ✅ Docker pull works (image download is fine)
- ❌ Image extraction/building fails

### Workaround 2: Remote BuildKit with Kubernetes Driver

Run BuildKit in a separate Kubernetes pod (requires RBAC permissions).

**Status:** ❌ NOT REQUIRED - Issue resolved with PVC storage

### Workaround 3: External Build Services

Build images externally and pull them.

**Status:** ❌ NOT REQUIRED - Local builds now work

## Related Issues

- **mo-9i6t:** Longhorn PVC filesystem corruption (separate issue, also affects builds)
- **mo-11q0:** Docker build overlayfs mount failures
- **mo-1rp9:** npm install blocker (related to filesystem issues)

## Summary

| Method | Status | Reason |
|--------|--------|--------|
| Docker BuildKit (original) | ❌ Failed | Nested overlayfs not supported |
| Docker BuildKit (fixed) | ✅ Works | Moved to PVC storage (ext4) |
| Buildah | ❌ Fails | User namespace restrictions |
| Kubernetes BuildKit | ⏸️ Not needed | Local builds work now |

## Success Criteria

- [x] Root cause identified (nested overlayfs in devpod)
- [x] Docker BuildKit overlayfs issue confirmed
- [x] Buildah tested - fails with user namespace errors
- [x] Resolution implemented - Docker moved to PVC storage
- [x] Docker builds verified working
- [x] Workarounds documented (for reference)

## Conclusion

**Docker BuildKit overlayfs issue is RESOLVED.**

The fix involved moving Docker's data directory from `/var/lib/docker` (on overlayfs) to `/home/coder/.docker-data` (on the Longhorn PVC with ext4). This eliminates the nested overlayfs problem and allows Docker builds to work correctly in the devpod environment.

**Current Status:** ✅ WORKING - Docker builds operational on PVC storage

**Commits:**
- `66fdf9a` - feat(mo-2392): Fix: Devpod storage layer - Docker overlayfs nested mount issue
- `df3e185` - feat(mo-2392): Add /dev/shm storage fix documentation
- `77dd63f` - feat(mo-2392): Blocker: Devpod storage layer corruption - overlayfs broken
