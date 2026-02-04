# Docker Build Solution for Devpod Environment

## Problem

Building Docker images inside the devpod fails with the following error:
```
mount source: "overlay", target: "/var/lib/docker/buildkit/containerd-overlayfs/...",
fstype: overlay, flags: 0, data: "...", err: invalid argument
```

This is caused by **nested overlay filesystems** - the devpod itself runs on an overlay filesystem (K3s/containerd), and Docker inside the devpod tries to create another overlay filesystem, which is not supported by the Linux kernel.

## Root Cause

- Devpod runs on `ardenone-cluster` with K3s
- K3s uses containerd with overlayfs storage driver
- Docker daemon inside the devpod also tries to use overlayfs
- Linux kernel does not allow nested overlay mounts (overlay-over-overlay)
- Error occurs at: `k8s/api/deployment.yml:22` and `k8s/frontend/deployment.yml:21`

## Solution: GitHub Actions CI/CD

Instead of building images in the devpod, we use **GitHub Actions** to build Docker images on GitHub's runners, which don't have the nested overlay limitation.

### Implementation

Two GitHub Actions workflows were created:

1. **`.github/workflows/build-api-image.yml`** - Builds `moltbook-api` image
2. **`.github/workflows/build-frontend-image.yml`** - Builds `moltbook-frontend` image

### Workflow Features

- **Triggers**: Automatically on push to main, PRs, and manual dispatch
- **Path-based**: Only triggers when relevant files change
- **Multi-platform**: Builds for `linux/amd64`
- **Registry**: Pushes to GitHub Container Registry (`ghcr.io`)
- **Caching**: Uses GitHub Actions cache for faster builds
- **Tagging**: Automatic semantic versioning and branch-based tags

### Image Tags

Images are pushed with multiple tags:
- `latest` - Latest build from main branch
- `main-<sha>` - Commit-specific tag (e.g., `main-abc1234`)
- `<branch>` - Branch-specific tag
- Semantic versions if tagged (e.g., `v1.2.3`, `1.2`, `1`)

### Deployment

The Kubernetes deployments in `k8s/api/deployment.yml` and `k8s/frontend/deployment.yml` are already configured to pull from:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

When you push changes to the `api/` or `moltbook-frontend/` directories, GitHub Actions will automatically:
1. Build the Docker image
2. Push it to GHCR with the `latest` tag
3. Kubernetes can pull the updated image on the next deployment or rollout restart

## Manual Image Pull

To manually update the running deployments after a new image is built:

```bash
# API deployment
kubectl rollout restart deployment/moltbook-api -n moltbook

# Frontend deployment
kubectl rollout restart deployment/moltbook-frontend -n moltbook
```

## Alternative Solutions Considered

### 1. fuse-overlayfs (Not Feasible)
- Would require modifying `/etc/docker/daemon.json` with elevated permissions
- Not persistent across devpod restarts
- Would require privileged container or host access

### 2. Docker Buildx with VFS (Not Feasible)
- VFS storage driver is very slow and disk-intensive
- Still requires daemon configuration changes
- Not practical for development workflow

### 3. External Build Server (Over-engineered)
- Would require additional infrastructure
- GitHub Actions provides this for free
- More complex to maintain

## Benefits of GitHub Actions Approach

1. **No local configuration needed** - Works out of the box
2. **Consistent build environment** - Same as production CI/CD
3. **Free for public repos** - No additional costs
4. **Automatic on push** - No manual intervention needed
5. **Cached layers** - Fast subsequent builds
6. **Version control** - All images are tagged and traceable

## Testing the Solution

After merging this fix:

1. Make a change to `api/src/index.js` or `moltbook-frontend/src/app/page.tsx`
2. Commit and push to main branch
3. Check GitHub Actions tab for running workflows
4. Once complete, images will be available at:
   - `ghcr.io/ardenone/moltbook-api:latest`
   - `ghcr.io/ardenone/moltbook-frontend:latest`

## Related Files

- `.github/workflows/build-api-image.yml` - API image build workflow
- `.github/workflows/build-frontend-image.yml` - Frontend image build workflow
- `k8s/api/deployment.yml` - API Kubernetes deployment (line 22, 34)
- `k8s/frontend/deployment.yml` - Frontend Kubernetes deployment (line 21)
- `api/Dockerfile` - API Docker build configuration
- `moltbook-frontend/Dockerfile` - Frontend Docker build configuration

## References

- [Docker in Docker and Overlay Filesystems](https://github.com/moby/moby/issues/41222)
- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Linux Kernel Overlay Limitations](https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html)
