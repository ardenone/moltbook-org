# BEAD MO-2392: Docker BuildKit Overlayfs Fix - RESOLVED

**Bead ID:** mo-2392
**Title:** Fix: Docker BuildKit overlayfs nested mount issue - RESOLVED
**Status:** ✅ COMPLETED - Docker builds working with PVC storage
**Created:** 2026-02-05
**Updated:** 2026-02-05 12:55 UTC

## Summary

This bead investigated Docker BuildKit overlayfs mount failures in the devpod environment. The issue was **RESOLVED by moving Docker's data directory from `/var/lib/docker` (on overlayfs) to `/home/coder/.docker-data` (on the Longhorn PVC with ext4 filesystem)**.

## Current Status: ALL SYSTEMS FUNCTIONAL

### What's Working (Verified 2026-02-05 12:55 UTC)
- **Docker builds**: ✅ WORKING - Docker storage moved to PVC (ext4)
- **Docker BuildKit**: ✅ WORKING - No longer on nested overlayfs
- **pnpm install**: Works with `--store-dir /tmp/pnpm-store` flag
- **npm run build**: Completes successfully with Turbopack (2.6s compile, 25 routes)
- **Frontend development**: Fully unblocked
- **node_modules**: Mounted on 16GB tmpfs (RAM disk)
- **Filesystem tests**: Basic operations pass on /tmp overlay

### What's Broken (on Longhorn PVC directly - EXPECTED)
- **npm install on PVC**: Fails with `TAR_ENTRY_ERROR ENOENT` - Expected, workaround used
- **Longhorn filesystem**: Has inode/directory entry corruption on ext4 - Expected, documented
- **Buildah**: Fails with user namespace restrictions - Not needed, Docker works

## Root Cause Analysis

### Primary Issue: Docker BuildKit Nested Overlayfs

**ORIGINAL PROBLEM:** Docker's data directory was on `/var/lib/docker` which itself was on an overlayfs filesystem with 26 layers from K3s containerd. Docker BuildKit could not create nested overlayfs mounts.

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

### Resolution: Move Docker to PVC Storage

**SOLUTION:** Moved Docker data directory to `/home/coder/.docker-data` on the Longhorn PVC with ext4 filesystem.

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

## Implementation Details

**Implemented in commit:** `66fdf9a`

1. **Created new Docker storage location:**
   ```bash
   mkdir -p /home/coder/.docker-data
   ```

2. **Configured Docker daemon:**
   - Docker Root Dir: `/home/coder/.docker-data` (was: `/var/lib/docker`)
   - Storage Driver: overlay2 (was: overlayfs with nesting)

3. **Configuration file:** `/etc/default/docker` with `DOCKER_OPTS`

## Verification Results (2026-02-05 12:55 UTC)

### Docker Build Test

```bash
$ docker info | grep "Docker Root Dir"
 Docker Root Dir: /home/coder/.docker-data

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

### Frontend Dependency Installation

```
=== Filesystem Health Tests ===
✓ Directory creation: OK
✓ Directory removal: OK
✓ File write/read: OK
✓ File deletion: OK
✓ TAR extraction: OK

=== Frontend Dependency Installation ===
Current node_modules size: 1.5G (on tmpfs)
✓ pnpm install with /tmp store: SUCCESS (711 packages, 1.5s)
✓ Build artifacts present (.next directory on tmpfs)
✓ npm run build: SUCCESS (25 routes compiled with Turbopack)
✓ tmpfs mounted: 16GB on node_modules, 8GB on .next
```

## PVC Health Details

- **PVC Name:** `coder-jeda-codespace-home`
- **PVC UID:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Namespace:** `devpod` (ardenone-cluster)
- **StorageClass:** `longhorn`
- **Capacity:** 60Gi
- **Usage:** 33G used / 26G available (57%)
- **Mount Point:** `/home/coder`
- **Filesystem:** ext4
- **Docker Storage:** `/home/coder/.docker-data` (on PVC)
- **Longhorn Volume Status:** "healthy" at block level, but ext4 filesystem has corruption

## Alternative Workarounds (Not Required After Fix)

These were investigated but are no longer needed since the issue is resolved:

### Buildah (LIMITED - User Namespace Issues)

**Status:** ❌ NOT WORKING - Buildah fails with user namespace errors

```bash
buildah bud -f Dockerfile -t myimage:latest .
# Error: insufficient UIDs or GIDs available in user namespace
# lchown /etc/shadow: invalid argument
```

**Why Buildah Fails:**
- Devpod runs in a restricted user namespace
- Buildah's rootless mode requires `/etc/subuid` and `/etc/subgid` mappings
- The kernel rejects `lchown` operations for certain UIDs/GIDs when extracting container images

### Kubernetes BuildKit Driver

**Status:** ❌ NOT REQUIRED - Local builds work now

Would require RBAC permissions to deploy BuildKit in a separate pod.

### External Build Services

**Status:** ❌ NOT REQUIRED - Local builds now work

## Related Beads

- **mo-9i6t** - Fix: Longhorn PVC filesystem corruption - Root cause analysis complete
- **mo-11q0** - Fix: Longhorn PVC filesystem corruption blocking npm install
- **mo-1rp9** - BLOCKER: Filesystem corruption on devpod Longhorn PVC (original investigation)
- **mo-3k3c** - Setup: CI/CD pipeline for Docker builds (created during investigation, not needed)
- **mo-27mf** - RBAC: Request BuildKit permissions in devpod namespace (created during investigation, not needed)

## Scripts Created

1. `scripts/pvc-health-check.sh` - Comprehensive PVC health diagnostic tool
2. `scripts/npm-install-workaround.sh` - Automated workaround implementation
3. `scripts/setup-frontend-tmpfs.sh` - Automated tmpfs setup for node_modules and .next
4. `~/.config/devpod-filesystem-fix/setup-node_modules-tmpfs.sh` - Auto-setup script
5. `~/.config/bashrc.d/devpod-filesystem-fix.sh` - Auto-run on cd

## How to Use the Workarounds

### Docker Builds (Now Working)

```bash
# Docker builds now work directly
docker build -t myimage:latest .

# Or with BuildKit
docker buildx build -t myimage:latest .
```

### Frontend Dependencies (Still Uses tmpfs)

```bash
# Option 1: Auto-run (when cd-ing into moltbook-frontend)
cd /home/coder/Research/moltbook-org/moltbook-frontend
# Script runs automatically via bashrc.d

# Option 2: Manual invocation
bash ~/.config/devpod-filesystem-fix/setup-node_modules-tmpfs.sh

# Option 3: Use the project script
bash /home/coder/Research/moltbook-org/scripts/setup-frontend-tmpfs.sh
```

## Permanent Fix Options

### Option 1: Recreate PVC with 3 Replicas (RECOMMENDED)

**Why This Is Necessary:**
1. **Single replica is the root cause** of filesystem corruption
2. **Filesystem corruption may recur** with 1 replica
3. **3 replicas provide HA** - automatic failover and self-healing
4. **PVC is 16 days old** - minimal accumulated state

**Steps to Recreate Devpod with 3 Replicas:**

```bash
# 1. Ensure all work is committed to git
cd /home/coder/Research/moltbook-org
git status

# 2. Delete the devpod deployment (stops the pod)
kubectl delete deployment coder-jeda-codespace -n devpod

# 3. Delete the PVC (WARNING: Deletes ALL data in /home/coder)
kubectl delete pvc coder-jeda-codespace-home -n devpod

# 4. Patch Longhorn to default to 3 replicas (optional, for future volumes)
# Edit Longhorn settings or create new StorageClass with 3 replicas

# 5. Recreate devpod - new PVC will be provisioned
# Via devpod CLI, ArgoCD, or Coder
```

## Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Docker builds | ✅ Working | Moved to PVC storage (ext4) |
| Docker BuildKit | ✅ Working | No nested overlayfs |
| pnpm install | ✅ Working | Uses tmpfs workaround |
| npm run build | ✅ Working | Turbopack, 25 routes |
| Buildah | ❌ Not working | User namespace issues (not needed) |
| Longhorn PVC | ⚠️ Degraded | 1 replica, filesystem corruption |

## Conclusion

**Status:** Development is **FULLY UNBLOCKED**. Docker builds now work after moving Docker storage to the PVC. The Longhorn PVC still has filesystem corruption (from single replica configuration) but workarounds are functional.

**Root Cause:**
1. **Docker issue:** Nested overlayfs - RESOLVED by moving to PVC storage
2. **npm issue:** Longhorn PVC corruption (1 replica) - Mitigated with tmpfs

**Immediate Status (2026-02-05 12:55 UTC):**
- Docker builds: Working (verified with test build)
- pnpm install: Working (711 packages, 1.5s)
- npm run build: Working (25 routes, Turbopack)
- Development: UNBLOCKED

**Next Steps:**
1. Continue development (all systems functional)
2. Schedule PVC recreation during maintenance window for 3-replica HA
3. Configure new PVC with 3 replicas for data redundancy

---

## Analysis Completed

**Date:** 2026-02-05
**Docker Issue:** RESOLVED - Moved to PVC storage
**npm Issue:** Mitigated - tmpfs workaround functional
**Longhorn PVC:** Degraded but working with workarounds
**Recommendation:** PVC recreation with 3 replicas for permanent fix
**Estimated Downtime:** 15-20 minutes
