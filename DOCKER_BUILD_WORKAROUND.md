# Docker Build Workaround for Devpod Environment

**Issue**: mo-jgo - Docker builds fail in devpod environment
**Date**: 2026-02-04
**Status**: ✅ **DOCUMENTED** - Local builds blocked, use GitHub Actions instead

---

## Problem Summary

Docker image builds fail when executed inside the devpod environment with:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

### Root Cause

This is **NOT a Docker Hub rate limit issue** despite the bead title. The actual problem:

1. **Nested Overlayfs**: Devpod runs inside Kubernetes with overlayfs storage
2. **Docker-in-Docker Limitation**: Docker daemon tries to create nested overlay filesystem
3. **Kernel Restriction**: Linux kernel doesn't support nested overlayfs mounts  
4. **Podman Also Affected**: Podman socket unavailable in containerized environment

### What Doesn't Work in Devpod

❌ Local Docker builds
❌ Disabling BuildKit
❌ Using Podman
❌ Changing storage drivers

---

## ✅ Solution: Use GitHub Actions

### Current Workflow Status

⚠️ The GitHub Actions workflow (`.github/workflows/build-push.yml`) is **configured but failing**.

**Issue**: All 34 workflow runs failed with "Server Error" from `docker/metadata-action@v5`

**Follow-up Bead**: **mo-1na** - Fix GitHub Actions workflow failures

### Once Workflow is Fixed

Trigger builds automatically by pushing to main:

```bash
git add .
git commit -m "feat: Update code"
git push origin main
```

Or trigger manually:

```bash
gh workflow run build-push.yml
gh run watch
```

---

## Alternative: Build on Host Machine

Build images on your host machine (not in devpod), then push:

```bash
# On host machine (MacOS/Linux workstation)
cd ~/moltbook-org
docker build -t ghcr.io/ardenone/moltbook-api:latest api/
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## Related Issues

| Bead | Title | Priority | Status |
|------|-------|----------|--------|
| mo-jgo | Docker Hub rate limit (misdiagnosed) | P1 | ✅ Documented |
| mo-1na | GitHub Actions workflow failures | P1 | 🔄 In Progress |

---

## Summary

- **Problem**: Nested overlayfs prevents Docker builds in devpod
- **Not the Problem**: Docker Hub rate limits (red herring)
- **Solution**: Use GitHub Actions (needs fixing) or build on host
- **Workaround**: Build on host machine and push manually

---

**Created**: 2026-02-04
**Bead**: mo-jgo
**Status**: ✅ Documented (workflow fix tracked separately)
