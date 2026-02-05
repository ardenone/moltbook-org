# Longhorn PVC Filesystem Corruption Workaround

## Problem

The devpod's Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has filesystem corruption that causes `npm install` to fail with `ENOTEMPTY: directory not empty, rmdir` errors.

## Symptoms

- `npm install` fails with `ENOTEMPTY` errors during cleanup phase
- `rm -rf node_modules` fails with `Directory not empty` errors
- Directories show as both "not empty" and "no such file or directory"
- Filesystem reports as clean with `e2fsck` but has operational inconsistencies

## Root Cause

The Longhorn PVC has filesystem-level corruption where:
1. Directory entries exist in metadata but don't exist on disk
2. Directories cannot be removed because the filesystem reports them as non-empty
3. This affects both `/home/coder` and `/tmp` directories

## Workaround

When `npm install` fails, use this workaround:

```bash
# 1. Create a clean working directory
mkdir -p /home/coder/npm-install-workaround

# 2. Copy package files to clean directory
cp /home/coder/Research/moltbook-org/moltbook-frontend/package.json /home/coder/npm-install-workaround/
cp /home/coder/Research/moltbook-org/moltbook-frontend/package-lock.json /home/coder/npm-install-workaround/

# 3. Install in clean directory (avoids corrupted filesystem areas)
cd /home/coder/npm-install-workaround
npm install --legacy-peer-deps --cache /home/coder/npm-install-workaround/.npm-cache

# 4. Replace the corrupted node_modules
mv /home/coder/Research/moltbook-org/moltbook-frontend/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/node_modules.failed
mv /home/coder/npm-install-workaround/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/node_modules

# 5. Copy the working package-lock.json
cp /home/coder/npm-install-workaround/package-lock.json /home/coder/Research/moltbook-org/moltbook-frontend/

# 6. Verify install works
cd /home/coder/Research/moltbook-org/moltbook-frontend
npm install --legacy-peer-deps
```

## Long-term Solution

The Longhorn PVC should be:
1. Backed up if needed
2. Deleted
3. Recreated with a fresh volume

This requires devpod recreation coordination.
