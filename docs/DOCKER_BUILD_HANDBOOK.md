# Docker Build Handbook for Moltbook Devpod Environment

**Task**: mo-2eaj - Fix: Docker overlay filesystem issue in devpod
**Status**: ✅ **DOCUMENTED WITH MULTIPLE SOLUTIONS**
**Last Updated**: 2026-02-05

---

## Executive Summary

**Problem**: Container images cannot be built directly inside the devpod environment due to Docker-in-Docker overlay filesystem limitations.

**Solution**: Images must be built externally using one of three approved methods.

**Required Images**:
- `ghcr.io/ardenone/moltbook-api:latest`
- `ghcr.io/ardenone/moltbook-frontend:latest`

---

## The Problem: Why Docker Builds Fail in Devpod

### Root Cause

1. **Nested Overlayfs**: Devpods run inside Kubernetes with overlayfs storage
2. **Docker-in-Docker Limitation**: Docker daemon tries to create nested overlay filesystem
3. **Kernel Restriction**: Linux kernel doesn't support nested overlayfs mounts
4. **Error Message**: `ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument`

### What Doesn't Work

- ❌ Local Docker builds with `docker build`
- ❌ Disabling BuildKit
- ❌ Using Podman socket
- ❌ Changing storage drivers

---

## Solution 1: GitHub Actions (Recommended for Production)

### Overview

Build images automatically on GitHub's Ubuntu runners when you push code changes.

### How to Use

```bash
# Automatic: Just push to main branch
git add .
git commit -m "feat: Update code"
git push origin main

# Manual: Trigger from CLI
gh workflow run build-images.yml
gh run watch

# Manual: Trigger from web
# Visit: https://github.com/ardenone/moltbook-org/actions/workflows/build-images.yml
```

### Workflow Location

`.github/workflows/build-images.yml`

### What Happens

1. Detects changes in `api/` or `moltbook-frontend/` directories
2. Builds both images on GitHub's Ubuntu runners
3. Pushes to `ghcr.io/ardenone/` automatically
4. Updates `k8s/kustomization.yml` with new image tags

### Advantages

- Zero manual intervention after setup
- No cluster resources consumed
- Integrated CI/CD with testing
- Automatic image tagging with git SHA

---

## Solution 2: Build on Local Machine (Quick Testing)

### Overview

Build images on your physical workstation (MacOS/Linux) with Docker installed, then push to registry.

### How to Use

```bash
# On your host machine (NOT in devpod)
cd ~/path/to/moltbook-org

# Set your GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Build and push using the provided script
./scripts/build-images.sh --push
```

### Manual Build Commands

```bash
# API Image
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker push ghcr.io/ardenone/moltbook-api:latest

# Frontend Image
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

### Script Location

`scripts/build-images.sh`

### Script Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Build images without pushing |
| `--push` | Push images to registry |
| `--api-only` | Build only the API image |
| `--frontend-only` | Build only the Frontend image |
| `--tag TAG` | Use specific tag instead of 'latest' |
| `--help` | Show help message |

### Authentication

The script requires `GITHUB_TOKEN` to be set:

```bash
# Option 1: Environment variable
export GITHUB_TOKEN=ghp_your_token_here

# Option 2: Inline
GITHUB_TOKEN=ghp_your_token_here ./scripts/build-images.sh --push

# Option 3: Using .env.local file
cp .env.local.template .env.local
# Edit .env.local with your token
source scripts/load-env.sh
./scripts/build-images.sh --push
```

### Advantages

- Full Docker control for debugging
- Fastest builds
- No resource limits
- Works offline (after base images cached)

---

## Solution 3: Kaniko (In-Cluster Builds)

### Overview

Kaniko is a daemonless container image builder that works in Kubernetes without Docker daemon or nested overlay issues.

### How to Use

```bash
# 1. Create GHCR credentials (one-time setup)
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  -n moltbook

# 2. Deploy Kaniko runner (one-time setup)
kubectl apply -f k8s/kaniko/

# 3. Build images using helper script
./scripts/kaniko-build.sh --all

# Or trigger directly with kubectl
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh
```

### Script Location

`scripts/kaniko-build.sh`

### Kaniko Manifests Location

`k8s/kaniko/`
- `build-runner-deployment.yml` - Kaniko deployment
- `build-scripts-configmap.yml` - Build scripts
- `ghcr-credentials-template.yml` - Credentials template
- `README.md` - Detailed documentation

### Advantages

- Build directly from devpod without leaving container
- Fast iterative builds
- Layer caching support
- No external dependencies

---

## Comparison Table

| Solution | Setup Complexity | Build Speed | Resource Usage | Automation | Best For |
|----------|----------------|-------------|----------------|------------|----------|
| **GitHub Actions** | Low | Medium | External (none) | ✅ Fully Auto | Production CI/CD |
| **Local Machine** | None | Fastest | Workstation | Manual | Quick Testing |
| **Kaniko** | Medium | Fast | Cluster resources | Semi-Auto | Devpod Development |

---

## Which Solution Should I Use?

### For Production Deployment
→ **GitHub Actions** (Solution 1)
- Push to `main` branch
- Images build and push automatically
- Zero manual intervention

### For Local Development/Testing
→ **Local Machine** (Solution 2)
- Build on your workstation
- Full Docker debugging capabilities
- Fastest for experimentation

### For Working Inside Devpod
→ **Kaniko** (Solution 3)
- Build without leaving devpod
- Integrated with Kubernetes
- Good for iterative development

---

## Troubleshooting

### Authentication Failed

```
Error: unauthorized: authentication required
```

**Solution**: Verify your GitHub token has `write:packages` scope:
```bash
# Check token is set
echo $GITHUB_TOKEN

# Create new token at: https://github.com/settings/tokens
# Required scopes: write:packages, read:packages
```

### GitHub Actions Workflow Fails

```bash
# Check workflow status
gh run list

# View specific run
gh run view <run-id>

# Re-run failed workflow
gh run rerun <run-id>
```

### Kaniko Build Fails

```bash
# Check deployment status
kubectl get deployment kaniko-build-runner -n moltbook

# View logs
kubectl logs -f deployment/kaniko-build-runner -n moltbook

# Verify credentials
kubectl get secret ghcr-credentials -n moltbook -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

### Build Script Prevents Execution in Devpod

This is **expected behavior**. The script detects containerized environments and prevents builds to avoid the overlay filesystem error.

**Solutions**:
1. Use GitHub Actions (push to main)
2. Build on local machine (not in devpod)
3. Use Kaniko for in-cluster builds

To force build anyway (experimental):
```bash
./scripts/build-images.sh --force --push
```

---

## Documentation Files

| File | Purpose |
|------|---------|
| `docs/DOCKER_BUILD_HANDBOOK.md` | This file - comprehensive handbook |
| `BUILD_GUIDE.md` | Detailed build instructions with authentication |
| `DOCKER_BUILD_WORKAROUND.md` | Original workaround documentation |
| `DOCKER_BUILD_SOLUTIONS.md` | Detailed comparison of all solutions |
| `k8s/kaniko/README.md` | Kaniko-specific documentation |
| `.github/workflows/build-images.yml` | GitHub Actions workflow |

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/build-images.sh` | Main Docker build script (with container detection) |
| `scripts/build-images-safe.sh` | Safe wrapper with devpod detection |
| `scripts/kaniko-build.sh` | Kaniko build helper script |
| `scripts/load-env.sh` | Load environment variables from .env.local |

---

## Verification

After building and pushing images, verify they are available:

```bash
# Via GitHub CLI
gh repo view ardenone/moltbook-org --json packages,packages{name}

# Via GitHub Web UI
# Visit: https://github.com/orgs/ardenone/packages

# Test pull (if you have Docker available)
docker pull ghcr.io/ardenone/moltbook-api:latest
docker pull ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Quick Reference Commands

### GitHub Actions (Recommended)
```bash
git push origin main  # Triggers automatic build
```

### Local Machine Build
```bash
export GITHUB_TOKEN=ghp_your_token_here
./scripts/build-images.sh --push
```

### Kaniko Build
```bash
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh
```

---

## Related Beads

| Bead | Title | Status |
|------|-------|--------|
| mo-jgo | Docker Hub rate limit (misdiagnosed) | ✅ Documented |
| mo-1na | GitHub Actions workflow failures | ✅ Completed |
| mo-1nh | Fix: Docker build overlay filesystem error in devpod | ✅ Completed |
| mo-2eaj | Fix: Docker overlay filesystem issue in devpod | ✅ **This bead** |
| mo-3bol | Fix: Docker build environment - node_modules ENOTEMPTY error | ✅ Completed |
| mo-3t8p | Fix: Docker overlay filesystem prevents image builds in devpod | ✅ Completed |

---

## Summary

**Problem**: Nested overlayfs prevents Docker builds in devpod environment.

**Solution**: Use one of three alternative build methods:
1. **GitHub Actions** - Automated CI/CD (recommended for production)
2. **Local Machine** - Manual builds on workstation (for testing)
3. **Kaniko** - In-cluster daemonless builds (for devpod development)

**Key Points**:
- The `build-images.sh` script automatically detects and prevents containerized builds
- GitHub Actions provides fully automated builds on push to main
- Local machine builds offer the fastest iteration for testing
- Kaniko enables building without leaving the devpod environment

---

**Created**: 2026-02-05
**Bead**: mo-2eaj
**Status**: ✅ **COMPLETE** - All solutions documented and operational
