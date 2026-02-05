# Devpod Storage Layer Diagnostic Report
**Date**: 2026-02-05
**Task**: mo-2392 - Blocker: Devpod storage layer corruption - overlayfs broken

## Executive Summary

The devpod's Docker/build operations are failing due to **nested overlayfs configuration**. The Docker daemon storage (`/var/lib/docker`) is mounted on an overlayfs with 26 layers from K3s containerd, and Docker's own overlayfs snapshotter cannot create valid mounts on top of an existing overlayfs.

**Status**: Longhorn PVC is healthy - this is NOT a filesystem corruption issue.

## Diagnostic Findings

### 1. Longhorn Volume Status: HEALTHY

```bash
kubectl get volumes.longhorn.io -n longhorn-system pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1
```

- **State**: attached
- **Robustness**: healthy
- **Node**: k3s-dell-micro
- **Size**: 60Gi
- **Age**: 16d
- **Filesystem**: ext4

The underlying PVC has no corruption or errors.

### 2. Root Cause: Nested Overlayfs

**Docker storage location:**
```
/var/lib/docker -> overlay (26 layers from K3s containerd)
```

**When Docker tries to create a container, it attempts:**
```
mount(overlay, target, fstype=overlay,
      data="workdir=...,upperdir=...,lowerdir=...") = -1 EINVAL (invalid argument)
```

This is the **"overlayfs on overlayfs"** problem - Linux kernel's overlayfs does not support nesting overlayfs mounts by default.

### 3. Failed Operations

1. **Docker container run:**
   ```
   docker: Error response from daemon: failed to mount: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
   ```

2. **Docker BuildKit:**
   ```
   ERROR: process "/bin/sh -c echo \"test\"" did not complete successfully: mount source: "overlay", target: "/var/lib/docker/buildkit/...", fstype: overlay, flags: 0, data: "...", err: invalid argument
   ```

3. **npm tar extraction**: Likely fails due to similar overlayfs issues during extraction.

### 4. Mount Stack Analysis

```
/dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1 (ext4)
  └─> /home/coder (PVC mount)
      └─> / (root overlay - 26 layers)
          └─> /var/lib/docker (Docker storage on overlay)
              └─> containerd overlayfs snapshotter (FAILS - nested overlay)
```

### 5. Environment Details

- **Kernel**: 6.12.63+deb13-amd64
- **Docker**: 29.0.1
- **Containerd**: containerd.io v2.1.5
- **Docker Storage Driver**: overlayfs (io.containerd.snapshotter.v1)
- **K3s Snapshotter**: overlayfs with 26 layers

## Recommendations

### Option 1: Configure Docker to Use Different Storage Driver (RECOMMENDED)

Change Docker to use a storage driver that doesn't require nested overlayfs:

**Try fuse-overlayfs:**
```bash
# Install fuse-overlayfs
apt-get update && apt-get install -y fuse-overlayfs

# Configure Docker to use it
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "storage-driver": "fuse-overlayfs"
}
EOF

# Restart Docker daemon
systemctl restart docker
```

### Option 2: Mount Docker Storage on Host Path

Configure Docker to store its data outside the overlayfs, directly on the PVC:

```json
{
  "data-root": "/home/coder/.docker-data",
  "storage-driver": "overlay2"
}
```

### Option 3: Use VFS Storage Driver (Fallback)

Only for non-performance-critical workloads:

```json
{
  "storage-driver": "vfs"
}
```

### Option 4: Recreate Devpod with Proper Storage Configuration

If the above fixes don't work, the devpod needs to be recreated with Docker storage backed by a non-overlayfs filesystem.

## Resolution Applied (2026-02-05)

### Fix: Configure Docker to Use PVC Directly

The issue was resolved by configuring Docker to store its data directly on the PVC (`/home/coder/.docker-data`) instead of using the nested overlayfs at `/var/lib/docker`.

**Changes made:**

1. **Created Docker data directory on PVC:**
   ```bash
   sudo mkdir -p /home/coder/.docker-data
   ```

2. **Configured Docker init script:**
   ```bash
   # /etc/default/docker
   DOCKER_OPTS="--data-root=/home/coder/.docker-data --storage-driver=overlay2"
   ```

3. **Restarted Docker daemon:**
   ```bash
   sudo service docker restart
   ```

### Verification

After the fix:
- `docker run --rm hello-world` - PASSED
- `docker build` with BuildKit - PASSED
- `npm install` with tar extraction - PASSED

**New Docker configuration:**
- Docker Root Dir: `/home/coder/.docker-data` (on PVC)
- Storage Driver: `overlay2`
- Filesystem: ext4 (Longhorn PVC)

This fix is **persistent across devpod restarts** via the `/etc/default/docker` configuration.

### Why This Works

By storing Docker data directly on the ext4 filesystem of the PVC (at `/home/coder/.docker-data`), Docker's overlay2 storage driver can create proper overlayfs mounts without nesting issues. The underlying ext4 filesystem on `/dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` supports overlayfs natively.

## Verification Commands

After applying fixes, verify with:

```bash
# Check Docker storage driver
docker info | grep "Storage Driver"

# Test basic container run
docker run --rm hello-world

# Test BuildKit
docker build --no-cache - <<'EOF'
FROM alpine
RUN echo "test"
EOF
```

## Additional Notes

- The ENOTEMPTY errors on directory removal are likely symptoms of the overlayfs nesting issue, not filesystem corruption
- tmpfs mounts for node_modules and .next are working correctly (not affected)
- The 26-layer overlay for root filesystem is from K3s containerd snapshotter
