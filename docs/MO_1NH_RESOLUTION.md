# mo-1nh: Docker Build Overlay Filesystem Error - RESOLVED

**Bead ID**: mo-1nh
**Title**: Fix: Docker build overlay filesystem error in devpod
**Status**: ✅ **RESOLVED**
**Date**: 2026-02-04

---

## Problem Summary

Docker builds failed in devpod environment with overlay filesystem mount error:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

### Root Cause

**Nested Overlayfs Limitation**: The devpod runs inside Kubernetes with overlayfs storage. Docker daemon inside the container tries to create nested overlay filesystems, which the Linux kernel doesn't support.

This is a **fundamental architectural limitation**, not a configuration issue.

---

## Solution Implemented

### ✅ Use GitHub Actions for Image Builds

The GitHub Actions workflow at `.github/workflows/build-push.yml` successfully builds images on GitHub's infrastructure, avoiding the nested overlayfs issue entirely.

**Workflow Features**:
- Builds both API and Frontend images
- Pushes to `ghcr.io/ardenone/*` registry
- Automatic triggering on push to main
- Manual triggering via `gh workflow run build-push.yml`
- Updates kustomization.yml with new image tags automatically

### Verification Results

Latest workflow run (ID: 21681571970):

| Component | Status | Build Time | Image |
|-----------|--------|------------|-------|
| API | ✅ Success | 40s | `ghcr.io/ardenone/moltbook-api` |
| Frontend | ⚠️ Build Error | 1m21s | `ghcr.io/ardenone/moltbook-frontend` |

**API Image**: Built successfully ✅
**Frontend Image**: Has separate build error (tracked in mo-1ux) ⚠️

---

## Why This Resolves mo-1nh

The overlay filesystem error is **completely resolved** by using GitHub Actions:

1. **No nested overlayfs**: GitHub Actions runners use standard Docker without containerization
2. **Proven success**: API image builds without any overlay errors
3. **Reproducible**: Multiple successful API builds in workflow history

The frontend failure is a **different issue** (React createContext bundling error), not related to overlay filesystems.

---

## Alternative Solutions (Not Needed)

These alternatives were considered but are unnecessary since GitHub Actions works:

1. **Build on host machine**: Would work but requires manual process
2. **Use remote Docker daemon**: Complex setup, unnecessary overhead
3. **Change storage driver**: Not possible in containerized environment

---

## Documentation Updates

Updated documentation to reflect solution:
- `BUILD_IMAGES.md` - Points to GitHub Actions as primary method
- `DOCKER_BUILD_WORKAROUND.md` - Documents the overlay issue and solution

---

## Related Issues

| Bead | Title | Status | Notes |
|------|-------|--------|-------|
| mo-1nh | Docker overlay filesystem error | ✅ Resolved | This bead |
| mo-jgo | Docker Hub rate limit (misdiagnosed) | ✅ Documented | Same root cause |
| mo-1ux | Frontend createContext build error | 🔄 New | Separate issue |

---

## Conclusion

**Resolution**: The overlay filesystem error is fully resolved by using GitHub Actions for builds instead of local devpod builds. The API image builds successfully, confirming the solution works.

**Next Steps**: The frontend build error (`createContext is not a function`) is tracked separately in bead mo-1ux.

---

**Task Completed**: 2026-02-04
**Worker**: claude-sonnet-charlie
**Verification**: API image successfully built via GitHub Actions ✅
