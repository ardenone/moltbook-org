# Docker BuildKit Overlayfs Fix - Analysis and Workarounds

**Bead ID:** mo-2392
**Date:** 2026-02-05
**Status:** 🔴 BLOCKER - Local builds not possible in devpod environment

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

### Workaround 4: External Build Services (RECOMMENDED)

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

## Recommended Solution: Use External Build Services

For this devpod environment, **external builds** are the recommended solution because:

1. **Docker BuildKit fails** - Nested overlayfs not supported
2. **Buildah fails** - User namespace restrictions
3. **Local builds not possible** - Container runtime constraints

### Recommended Workflows

#### Option 1: CI/CD Pipeline Builds (RECOMMENDED)

Use GitHub Actions, GitLab CI, or similar to build images:

```yaml
# .github/workflows/docker-build.yml
name: Docker Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build image
        run: docker build -t registry.example.com/myimage:${{ github.sha }} .
      - name: Push image
        run: docker push registry.example.com/myimage:${{ github.sha }}
```

#### Option 2: Pre-built Images

Use official or organization pre-built images:

```bash
# Pull pre-built images instead of building locally
docker pull node:20-alpine
docker pull python:3.12-slim
docker pull your-registry.com/custom-image:latest
```

#### Option 3: Remote BuildKit with RBAC (Future)

Request RBAC permissions to use Kubernetes BuildKit driver:

```bash
# Requires RBAC (currently unavailable)
kubectl create serviceaccount buildkit -n devpod
kubectl create rolebinding buildkit --role=buildkit --serviceaccount=devpod:buildkit
docker buildx create --use --driver=kubernetes --driver-opt=namespace=devpod
```

## Related Issues

- **mo-9i6t:** Longhorn PVC filesystem corruption (separate issue, also affects builds)
- **mo-11q0:** Docker build overlayfs mount failures
- **mo-1rp9:** npm install blocker (related to filesystem issues)

## Summary of Findings

| Method | Status | Reason |
|--------|--------|--------|
| Docker BuildKit | ❌ Fails | Nested overlayfs not supported |
| Buildah | ❌ Fails | User namespace restrictions |
| Kubernetes BuildKit | ❌ Blocked | Requires RBAC permissions |
| External CI/CD | ✅ Works | Use GitHub Actions / GitLab CI |
| Pre-built images | ✅ Works | Pull from registry |

## Next Steps

1. ✅ **Root cause identified** - Nested overlayfs + user namespace issues
2. ⏳ **Set up CI/CD pipeline** for image builds
3. ⏳ **Request RBAC permissions** for Kubernetes BuildKit driver
4. ⏳ **Document build workflows** for the team

## Success Criteria

- [x] Root cause identified (nested overlayfs + user namespaces)
- [x] Docker BuildKit overlayfs issue confirmed
- [x] Buildah tested - fails with user namespace errors
- [x] Workarounds documented (external CI/CD, pre-built images)
- [ ] Set up CI/CD pipeline for automated builds
- [ ] Document team migration guide

## Conclusion

**Local Docker image builds are not possible** in this devpod environment due to:

1. **Docker BuildKit** - Cannot create nested overlayfs mounts
2. **Buildah** - User namespace restrictions prevent image extraction

### Recommended Actions

1. **Immediate:** Use pre-built images for development
2. **Short-term:** Set up CI/CD pipeline for image builds (GitHub Actions, GitLab CI)
3. **Long-term:** Request RBAC permissions for Kubernetes BuildKit driver

**Status:** 🔴 LOCAL BUILDS NOT POSSIBLE - Use external CI/CD or pre-built images
