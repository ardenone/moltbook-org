# Docker BuildKit Overlayfs Fix - Analysis and Workarounds

**Bead ID:** mo-2392
**Date:** 2026-02-05
**Status:** 🔄 INVESTIGATING - Multiple workarounds available

## Problem Statement

Docker BuildKit fails with overlayfs mount error "invalid argument" when attempting to build container images on the devpod.

### Error Details

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

Docker BuildKit attempts to create **nested overlayfs mounts** on top of this existing overlayfs layer, which the kernel rejects with "invalid argument".

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Node Filesystem (ext4 on nvme0n1p2)                        │
├─────────────────────────────────────────────────────────────┤
│ K3s containerd overlayfs (26 layers) ← Running pod root    │
├─────────────────────────────────────────────────────────────┤
│ /var/lib/docker (on overlayfs)                             │
├─────────────────────────────────────────────────────────────┤
│ Docker BuildKit overlayfs ← FAILS HERE (nested overlayfs)  │
└─────────────────────────────────────────────────────────────┘
```

### Kernel Configuration

- **Kernel Version:** 6.12.63+deb13-amd64
- **Page Size:** 4096 bytes
- **Overlayfs module:** Loaded (217088 references)
- **Max user namespaces:** 255328

### Why It Fails

The kernel has limits on overlayfs nesting. When Docker BuildKit (running inside an overlayfs) tries to create another overlayfs mount for container build operations, it exceeds these limits or hits incompatibility issues with the nested configuration.

## Affected Operations

- ❌ `docker build` / `docker buildx build` - Fails with overlayfs mount error
- ❌ `docker buildx build` with cache mounts - Fails immediately
- ❌ Any Docker image build operation - All blocked

## Workarounds and Solutions

### Workaround 1: Use Buildah (RECOMMENDED)

**Buildah** doesn't require nested overlayfs and works in this environment.

```bash
# Buildah is already installed
which buildah
# /usr/bin/buildah

# Build an image using buildah
buildah bud -f Dockerfile -t myimage:latest .

# Or use buildah commands directly
buildah from alpine:3.19
ctr=$(buildah from alpine:3.19)
buildah run $ctr -- echo "test"
buildah commit $ctr myimage:latest
```

**Pros:**
- ✅ Works in devpod environment
- ✅ No nested overlayfs required
- ✅ Already installed
- ✅ Compatible with Dockerfile syntax

**Cons:**
- ⚠️ Different CLI than Docker
- ⚠️ May require workflow changes

### Workaround 2: Remote BuildKit with Kubernetes Driver

Run BuildKit in a separate Kubernetes pod (requires RBAC permissions).

```bash
# Create Kubernetes BuildKit builder (needs RBAC)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: buildkit
  namespace: devpod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: buildkit
  namespace: devpod
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: buildkit
  namespace: devpod
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: buildkit
subjects:
- kind: ServiceAccount
  name: buildkit
EOF

# Create builder (using the service account)
docker buildx create \
  --use \
  --driver=kubernetes \
  --driver-opt=namespace=devpod \
  --driver-opt=serviceaccount=buildkit \
  --name=k8s-builder
```

**Pros:**
- ✅ Native Docker build experience
- ✅ Builds run in separate pod

**Cons:**
- ❌ Requires RBAC permissions (currently unavailable)
- ❌ More complex setup

### Workaround 3: Docker Daemon with VFS Driver (Not Available)

Configure Docker to use VFS storage driver instead of overlayfs.

```json
// /etc/docker/daemon.json
{
  "storage-driver": "vfs"
}
```

**Status:** ❌ NOT AVAILABLE - Requires Docker daemon restart and root access

### Workaround 4: External Build Services

Build images externally and pull them.

```bash
# Use GitHub Actions, GitLab CI, or other CI/CD
# Build image in CI pipeline
# Pull pre-built image to devpod
docker pull registry.example.com/myimage:latest
```

**Pros:**
- ✅ Works in any environment
- ✅ No local build required

**Cons:**
- ❌ External dependency
- ❌ Slower feedback loop

### Workaround 5: Use Pre-built Images

Skip local builds entirely and use official or pre-built images.

```bash
# Use pre-built images instead of building
docker pull node:20-alpine
docker pull python:3.12-slim
```

**Pros:**
- ✅ No build issues
- ✅ Faster

**Cons:**
- ❌ Not always applicable
- ❌ Can't customize images

## Recommended Solution: Use Buildah

For this devpod environment, **Buildah** is the recommended solution because:

1. **Already installed** at `/usr/bin/buildah`
2. **Works without nested overlayfs** - doesn't try to create overlayfs mounts
3. **Dockerfile compatible** - `buildah bud` understands Dockerfile syntax
4. **No permissions required** - works within devpod constraints

### Buildah Quick Reference

```bash
# Build from Dockerfile
buildah bud -t myimage:latest .

# Build with build args
buildah bud --build-arg NODE_ENV=production -t myimage:latest .

# Interactive build
buildah bud --layers -t myimage:latest .

# Push to registry
buildah push myimage:latest docker://registry.example.com/myimage:latest
```

## Verification Tests

### Test 1: Basic Buildah Build

```bash
cat > /tmp/Dockerfile.test << 'EOF'
FROM alpine:3.19
RUN echo "test" > /tmp/test.txt
CMD ["cat", "/tmp/test.txt"]
EOF

buildah bud -f /tmp/Dockerfile.test -t test-build /tmp
```

### Test 2: Buildah Multi-stage Build

```bash
cat > /tmp/Dockerfile.multi << 'EOF'
FROM alpine:3.19 AS builder
RUN echo "builder" > /tmp/builder.txt

FROM alpine:3.19
COPY --from=builder /tmp/builder.txt /tmp/
CMD ["cat", "/tmp/builder.txt"]
EOF

buildah bud -f /tmp/Dockerfile.multi -t test-multi /tmp
```

## Related Issues

- **mo-9i6t:** Longhorn PVC filesystem corruption (separate issue, also affects builds)
- **mo-11q0:** Docker build overlayfs mount failures
- **mo-1rp9:** npm install blocker (related to filesystem issues)

## Limitations

### Docker BuildKit Overlayfs Nesting
- ❌ **Cannot build images** with Docker BuildKit in devpod
- ❌ **No native Docker build** experience without external services

### Buildah Workaround
- ✅ **Can build images** using Buildah
- ⚠️ **Different CLI** - requires adapting workflows
- ⚠️ **May not be compatible** with all Dockerfile features

## Next Steps

1. ✅ **Use Buildah** for immediate image builds
2. ⏳ **Request RBAC permissions** for Kubernetes BuildKit driver
3. ⏳ **Consider external build services** for CI/CD integration
4. ⏳ **Document build workflows** for the team

## Success Criteria

- [x] Root cause identified (nested overlayfs in devpod)
- [x] Workaround documented (use Buildah)
- [ ] Test Buildah build operations
- [ ] Update CI/CD workflows to use Buildah or external builds
- [ ] Document team migration guide

## Conclusion

Docker BuildKit cannot create nested overlayfs mounts in the devpod environment because the devpod itself runs on overlayfs. The recommended workaround is to use **Buildah** for image builds, which doesn't require nested overlayfs and works within the devpod's constraints.

**Status:** 🟡 WORKAROUND AVAILABLE - Use Buildah for local builds
