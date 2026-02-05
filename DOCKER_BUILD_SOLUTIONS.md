# Docker Build Solutions for Moltbook

**Updated**: 2026-02-05
**Status**: ✅ Multiple Solutions Available

---

## Problem Summary

Docker image builds fail in devpod environments due to **nested overlay filesystem** limitations. When Docker-in-Docker tries to create overlay mounts within an already overlay-based container storage, the Linux kernel rejects it with:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

### Root Cause

- Devpods run inside Kubernetes with overlayfs storage
- Docker daemon creates nested overlay filesystems
- Linux kernel doesn't support nested overlayfs
- Affects both Docker and Podman in containerized environments

---

## Solutions

### ✅ Solution 1: GitHub Actions (Recommended for CI/CD)

**Best for**: Production builds, automated deployments, team collaboration

The `.github/workflows/build-push.yml` workflow builds images on GitHub runners (Ubuntu VMs) without nested overlay issues.

**Pros**:
- Native Docker environment on Ubuntu runners
- Automated builds on push to main
- No cluster resources consumed
- CI/CD integration with tests

**Cons**:
- External dependency
- Network latency for large images

**Trigger Builds**:
```bash
# Automatic: Push to main branch
git push origin main

# Manual: Using GitHub CLI
gh workflow run build-push.yml
gh run watch

# Manual: Using web interface
# Visit: https://github.com/ardenone/moltbook-org/actions/workflows/build-push.yml
```

---

### ✅ Solution 2: Kaniko in Kubernetes (Recommended for Devpod)

**Best for**: Local development in devpod, cluster-internal builds

Kaniko is a daemonless container image builder that works without Docker daemon or privileged mode. It's deployed as a long-running Deployment in the cluster.

**Pros**:
- No nested overlay issues
- Runs in-cluster, no external dependency
- Fast builds for local development
- Layer caching support

**Cons**:
- Consumes cluster resources
- Requires initial setup

**Quick Start**:
```bash
# 1. Create GHCR credentials (one-time setup)
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  -n moltbook

# 2. Deploy Kaniko runner (one-time setup)
kubectl apply -f k8s/kaniko/

# 3. Build images
./scripts/kaniko-build.sh --all

# Or with kubectl directly
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh
```

**Helper Script Options**:
```bash
./scripts/kaniko-build.sh --help                    # Show all options
./scripts/kaniko-build.sh --deploy --all            # Deploy and build
./scripts/kaniko-build.sh --api-only --tag v1.0.0   # Build API with tag
./scripts/kaniko-build.sh --watch --all             # Watch build logs
```

**See Also**: `k8s/kaniko/README.md` for detailed Kaniko documentation

---

### ✅ Solution 3: Build on Host Machine

**Best for**: Quick local builds, testing Dockerfiles

Build images on your physical workstation (MacOS/Linux) outside of devpod, then push to registry.

**Pros**:
- Full Docker control
- Fastest builds
- No resource limits

**Cons**:
- Requires leaving devpod
- Manual process

**Commands**:
```bash
# On your host machine (not in devpod)
cd ~/path/to/moltbook-org

# Build images
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin

# Push images
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Comparison Table

| Solution | Setup Complexity | Build Speed | Resource Usage | Automation | Best For |
|----------|----------------|-------------|----------------|------------|----------|
| **GitHub Actions** | Low | Medium | None (external) | ✅ Auto | Production CI/CD |
| **Kaniko (K8s)** | Medium | Fast | Cluster resources | Manual | Devpod development |
| **Host Machine** | None | Fastest | Workstation | Manual | Quick testing |

---

## Which Solution Should I Use?

### For Production/CI/CD
→ **GitHub Actions** (`.github/workflows/build-push.yml`)
- Automated builds on push
- No manual intervention
- Integrated with deployment pipeline

### For Devpod Development
→ **Kaniko** (`k8s/kaniko/`)
- Build directly from devpod
- No need to leave container
- Fast iterative builds

### For Quick Testing
→ **Host Machine**
- Fastest for experimentation
- Full Docker debugging capabilities

---

## File Structure

```
moltbook-org/
├── .github/workflows/
│   └── build-push.yml              # GitHub Actions workflow
├── k8s/kaniko/
│   ├── build-runner-deployment.yml  # Kaniko deployment
│   ├── build-scripts-configmap.yml  # Build scripts
│   ├── ghcr-credentials-template.yml # Credentials template
│   └── README.md                    # Kaniko documentation
├── scripts/
│   ├── kaniko-build.sh              # Kaniko helper script
│   ├── build-images.sh              # Traditional Docker build script
│   └── build-images-safe.sh         # Safe wrapper with devpod detection
├── api/
│   └── Dockerfile
└── moltbook-frontend/
    └── Dockerfile
```

---

## Troubleshooting

### GitHub Actions Failures

If workflow runs fail:
1. Check secrets: `gh secret list`
2. Verify GITHUB_TOKEN has `write:packages` scope
3. Check workflow logs: `gh run list && gh run view`

### Kaniko Build Failures

If Kaniko builds fail:
```bash
# Check deployment status
kubectl get deployment kaniko-build-runner -n moltbook

# View logs
kubectl logs -f deployment/kaniko-build-runner -n moltbook

# Verify credentials
kubectl get secret ghcr-credentials -n moltbook -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Interactive debugging
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- sh
```

### Docker Build Errors in Devpod

If you try to build with Docker directly in devpod:
```bash
# Use the safe wrapper - it will prevent the error
./scripts/build-images-safe.sh

# Or use Kaniko instead
./scripts/kaniko-build.sh --all
```

---

## Related Beads

| Bead | Title | Status |
|------|-------|--------|
| mo-jgo | Docker Hub rate limit (misdiagnosed) | ✅ Documented |
| mo-1na | GitHub Actions workflow failures | ✅ Completed |
| mo-1nh | Fix: Docker build overlay filesystem error in devpod | ✅ Completed |
| mo-3bol | Fix: Docker build environment - node_modules ENOTEMPTY error | ✅ Completed |
| mo-3t8p | Fix: Docker overlay filesystem prevents image builds in devpod | ✅ **COMPLETED** |

---

## Summary

**Problem**: Nested overlayfs prevents Docker builds in devpod

**Solutions Available**:
1. ✅ **GitHub Actions** - Automated CI/CD builds (recommended for production)
2. ✅ **Kaniko** - In-cluster daemonless builds (recommended for devpod)
3. ✅ **Host Machine** - Manual local builds (for quick testing)

**Recommendation**: Use GitHub Actions for automated builds and Kaniko for local development in devpod.
