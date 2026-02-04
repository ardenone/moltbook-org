# Task mo-1nh Resolution Summary

## Problem
Docker build fails with overlay filesystem error when trying to build moltbook-api and moltbook-frontend images in devpod:
```
mount source: overlay... err: invalid argument
```

## Root Cause
- Devpod runs as a container inside Kubernetes cluster (container-in-container)
- Host filesystem uses overlayfs (k3s/containerd snapshotter)
- Docker inside the container also attempts to use overlayfs
- Linux kernel does not support nested overlay mounts
- Result: "invalid argument" error when Docker buildkit tries to create overlay mounts

## Solution Implemented
**Use GitHub Actions workflow to build images externally** instead of building inside the devpod.

### Why This Solution?
1. ✅ **Already implemented** - `.github/workflows/build-push.yml` exists and works
2. ✅ **Automated** - Triggers on push to main branch
3. ✅ **Integrated** - Automatically updates Kubernetes manifests with new image tags
4. ✅ **CI/CD ready** - Includes caching, SBOM, provenance, and security features
5. ✅ **No devpod changes needed** - Works out of the box

### Files Created/Modified
1. **DOCKER_BUILD.md** - Comprehensive documentation explaining:
   - The problem and root cause
   - How the GitHub Actions workflow works
   - Developer workflow for building images
   - Troubleshooting guide
   - Alternative solutions (not recommended)

2. **scripts/check-build-status.sh** - Helper script to:
   - Check recent workflow runs
   - Display build status
   - Show useful commands for developers

3. **README.md** - Updated with:
   - Quick links to docker build documentation
   - Warning about not building in devpod
   - Quick start commands for developers

## Developer Workflow

### Standard Flow (Automatic)
```bash
# 1. Make code changes in api/ or moltbook-frontend/
# 2. Commit and push
git add .
git commit -m "feat: Your feature"
git push origin main

# 3. GitHub Actions automatically:
#    - Builds Docker images
#    - Pushes to ghcr.io/ardenone/moltbook-{api,frontend}
#    - Updates k8s/kustomization.yml with new tags
#    - ArgoCD deploys new images
```

### Manual Trigger
```bash
# Trigger build without code changes
gh workflow run build-push.yml

# Check status
./scripts/check-build-status.sh

# Watch in real-time
gh run watch
```

## Testing Results
- ✅ Documentation created and committed
- ✅ Helper script created and tested
- ✅ Git push triggered GitHub Actions workflow
- ✅ API build successful
- ⚠️ Frontend build has pre-existing issues (unrelated to overlay filesystem)
- ✅ Follow-up bead created: mo-3tvt for frontend build issues

## Alternative Solutions Considered

### 1. Fix Docker Buildkit Configuration
Configure Docker to use VFS storage driver:
- **Rejected**: Significantly slower, uses more disk space, not recommended

### 2. Build on Local Machine
Build images locally and push manually:
- **Rejected**: No automation, inconsistent environments, manual process

### 3. Use Kaniko or Buildah
Alternative build tools that don't require Docker daemon:
- **Rejected**: Additional complexity, different tools, GitHub Actions solution is simpler

## Technical Details

### Container-in-Container Architecture
```
ardenone-cluster
  └─→ devpod namespace
        └─→ devpod pod (overlayfs mount from k3s)
              └─→ Docker daemon
                    └─→ Attempts to create overlay mount ❌
```

### External Build Architecture
```
GitHub (code push)
  └─→ GitHub Actions (ubuntu-latest runner)
        └─→ Docker Buildx (clean environment)
              └─→ Build images ✅
                    └─→ Push to GHCR ✅
                          └─→ ArgoCD pulls and deploys ✅
```

## Verification

### Check Images in GHCR
```bash
gh api /user/packages/container/moltbook-api/versions
gh api /user/packages/container/moltbook-frontend/versions
```

### Check Deployed Images in Cluster
```bash
kubectl get deploy -n moltbook -o yaml | grep image:
```

### Verify Kustomization Tags
```bash
cat k8s/kustomization.yml | grep -A 2 "images:"
```

## Related Beads
- **mo-1nh**: This task (Docker overlay filesystem fix)
- **mo-3tvt**: Frontend build failure (follow-up)
- **mo-saz**: Original deployment task

## Conclusion
The Docker overlay filesystem error in devpod is **resolved** by using the existing GitHub Actions workflow for external image builds. This is the recommended and most maintainable solution.

**No builds should be attempted inside the devpod** - all Docker image builds should go through GitHub Actions.
