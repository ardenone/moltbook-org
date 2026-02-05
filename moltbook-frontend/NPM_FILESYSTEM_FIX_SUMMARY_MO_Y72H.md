# NPM Filesystem Corruption Fix Summary - Bead MO-Y72H

## Issue
The devpod's Longhorn PVC had filesystem corruption causing `pnpm install` and `npm install` to fail with TAR_ENTRY_ERROR and ENOTEMPTY errors.

## Root Cause
- Longhorn PVC filesystem corruption (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`)
- Directories showing as both "not empty" and "no such file or directory"
- Corrupted `node_modules.corrupted/` directory (445MB)
- Affected both `/home/coder` and `/tmp` directories in the devpod

## Solution Applied
1. **Identified the problem**: Both npm and pnpm installs failed with TAR_ENTRY_ERROR and ENOTEMPTY errors
2. **Used clean location workaround**: Installed packages in `/tmp/npm-install-clean/` using pnpm with a separate store directory
3. **Replaced node_modules**: Used tar to transfer the successfully installed `node_modules` to avoid filesystem corruption issues with cp/mv

## Commands Used
```bash
# 1. Create clean working directory in /tmp (different filesystem)
mkdir -p /tmp/npm-install-clean

# 2. Copy package files
cp /home/coder/Research/moltbook-org/moltbook-frontend/package.json /tmp/npm-install-clean/
cp /home/coder/Research/moltbook-org/moltbook-frontend/pnpm-lock.yaml /tmp/npm-install-clean/
cp /home/coder/Research/moltbook-org/moltbook-frontend/.npmrc /tmp/npm-install-clean/

# 3. Install in clean directory using pnpm with separate store
cd /tmp/npm-install-clean
npx pnpm install --store-dir /tmp/pnpm-store --force

# 4. Use tar to transfer (avoids filesystem corruption issues with cp/mv)
cd /home/coder/Research/moltbook-org/moltbook-frontend
tar cf - -C /tmp/npm-install-clean node_modules | tar xf - -

# 5. Verify install works
npx pnpm install --store-dir /tmp/pnpm-store
```

## Verification
```bash
npx pnpm install --store-dir /tmp/pnpm-store
# Output: Packages: +764
#         Done in 1m 39.6s using pnpm v10.28.2
#         All 764 packages successfully installed
```

## Status
- **RESOLVED**: pnpm install now works successfully
- **Note**: The build has a separate webpack configuration issue (Next.js 16 issuerLayer error) that is unrelated to filesystem corruption

## Related Files
- `FILESYSTEM_WORKAROUND.md` - Original workaround documentation (uses npm, but pnpm works better)
- `node_modules/` - Now functional (1.5GB, installed via pnpm)

## Key Learnings
1. **tar > cp/mv**: When dealing with filesystem corruption, use tar for transfers instead of cp/mv
2. **pnpm > npm**: pnpm handles the corrupted filesystem better than npm for this project
3. **/tmp workaround**: Installing in /tmp (different filesystem) avoids the Longhorn PVC corruption issues
4. **Separate store**: Using `--store-dir /tmp/pnpm-store` keeps store away from corrupted filesystem

## Long-term Recommendation
The Longhorn PVC should be recreated to prevent future filesystem corruption issues. When reinstalling, use the `/tmp` workaround directory with pnpm.
