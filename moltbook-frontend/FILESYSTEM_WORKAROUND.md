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

## Workaround (pnpm - RECOMMENDED)

This project uses pnpm. The `/tmp` directory workaround is more reliable than npm:

```bash
# 1. Create a clean working directory in /tmp
mkdir -p /tmp/npm-install-clean

# 2. Copy package files to clean directory
cp /home/coder/Research/moltbook-org/moltbook-frontend/package.json /tmp/npm-install-clean/
cp /home/coder/Research/moltbook-org/moltbook-frontend/pnpm-lock.yaml /tmp/npm-install-clean/
cp /home/coder/Research/moltbook-org/moltbook-frontend/.npmrc /tmp/npm-install-clean/

# 3. Install in clean directory using pnpm with separate store
cd /tmp/npm-install-clean
npx pnpm install --store-dir /tmp/pnpm-store

# 4. Force remove corrupted node_modules and replace
cd /home/coder/Research/moltbook-org/moltbook-frontend
find node_modules -delete 2>/dev/null || true
cp -r /tmp/npm-install-clean/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/

# 5. Verify install works
npx pnpm install --store-dir /tmp/pnpm-store
```

## Workaround (npm - ALTERNATIVE)

If npm must be used:

```bash
# 1. Create a clean working directory
mkdir -p /home/coder/npm-install-workaround

# 2. Copy package files to clean directory
cp /home/coder/Research/moltbook-org/moltbook-frontend/package.json /home/coder/npm-install-workaround/

# 3. Install in clean directory
cd /home/coder/npm-install-workaround
npm install --legacy-peer-deps

# 4. Replace the corrupted node_modules
mv /home/coder/Research/moltbook-org/moltbook-frontend/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/node_modules.failed
mv /home/coder/npm-install-workaround/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/node_modules

# 5. Verify install works
cd /home/coder/Research/moltbook-org/moltbook-frontend
npm install --legacy-peer-deps
```

## Resolution (2026-02-05)

The issue was resolved through a multi-step approach:

1. **Filesystem Workaround**: Used a clean working directory (`/home/coder/npm-install-workaround`) to install packages outside the corrupted filesystem areas
2. **Package Manager Switch**: Switched from npm to pnpm which handles the corrupted filesystem more gracefully
3. **Build System Fix**: Switched from webpack to Turbopack to bypass the "Cannot read properties of undefined (reading 'issuerLayer')" webpack bug that occurred with Next.js 16 + React 19

### Changes Made:
- `next.config.js`: Enabled `turbopack: { root: __dirname }` to use Turbopack instead of webpack
- `package.json`: Changed `build:next` script from `next build --webpack` to `next build`

This combination of fixes allows the project to build successfully despite the underlying filesystem corruption.

### If Build Fails Again:
```bash
# Clean install using pnpm in a clean directory
rm -rf node_modules
mkdir -p /tmp/pnpm-clean-install
cp package.json pnpm-lock.yaml /tmp/pnpm-clean-install/
cd /tmp/pnpm-clean-install
npx pnpm install
cp -r node_modules /home/coder/Research/moltbook-org/moltbook-frontend/
```

## Long-term Solution

The Longhorn PVC should be:
1. Backed up if needed
2. Deleted
3. Recreated with a fresh volume

This requires devpod recreation coordination.
