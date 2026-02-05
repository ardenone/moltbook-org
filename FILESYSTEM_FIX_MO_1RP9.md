# Filesystem Fix for Devpod npm install Issues

## Issue Summary

**Bead ID:** mo-1rp9

The devpod's underlying Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) exhibits filesystem issues causing `npm install` to fail repeatedly with `ENOENT` errors when creating directories in `node_modules`.

## Error Patterns Observed

```
npm warn tar TAR_ENTRY_ERROR ENOENT: no such file or directory, lstat
npm warn cleanup ENOTEMPTY: directory not empty, rmdir
npm error ENOENT: Cannot cd into 'node_modules/...'
```

## Root Cause Analysis

1. **Longhorn Volume Status:** Healthy (confirmed via `kubectl get volumes.longhorn.io`)
2. **Filesystem Type:** ext4 mounted at `/home/coder`
3. **Issue:** Corrupted directory entries in `node_modules` that cannot be cleaned or recreated via npm

## Solution Implemented

### Primary Fix: Use pnpm instead of npm

**Why pnpm works better:**
- Uses content-addressable storage instead of nested `node_modules`
- Better handling of filesystem operations during install
- More resilient to directory creation failures

**Installation:**
```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

**Usage:**
```bash
# Install dependencies
/home/coder/.local/share/pnpm/.tools/pnpm-exe/10.28.2/pnpm install

# Build
pnpm run build
```

### Alternative: Docker Build (for persistent issues)

When filesystem corruption persists, use Docker for builds:

```bash
# Build in Docker container with clean filesystem layer
docker run --rm -v "$(pwd):/app" -w /app node:20-alpine sh -c "corepack enable && pnpm install && pnpm run build"
```

Or use the helper script:
```bash
./scripts/pnpm-helper.sh docker-build
```

## Helper Script

A helper script has been created at `scripts/pnpm-helper.sh`:

```bash
# Install with pnpm
./scripts/pnpm-helper.sh install

# Build with pnpm
./scripts/pnpm-helper.sh build

# Build in Docker (recommended for persistent issues)
./scripts/pnpm-helper.sh docker-build
```

## Package.json Updates

Updated `package.json` to include:
- `build:next` - Direct Next.js build command
- `build:docker` - Docker-based build command
- Modified `build` script to use pnpm

## Recommendations

1. **Use pnpm** as the default package manager for this project (lockfile already exists)
2. **Docker builds** are recommended for CI/CD to avoid filesystem issues
3. **Monitor** the Longhorn volume health regularly
4. **Consider** recreating the devpod if issues persist after all workarounds

## Related Files

- `scripts/pnpm-helper.sh` - Helper script for pnpm operations
- `package.json` - Updated build scripts
