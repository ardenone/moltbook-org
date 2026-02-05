# NPM Filesystem Corruption Fix Summary - Bead MO-Y72H

## Issue
The devpod's Longhorn PVC had filesystem corruption causing `pnpm install` and `npm install` to fail with TAR_ENTRY_ERROR and ENOTEMPTY errors.

## Root Cause
- Longhorn PVC filesystem corruption (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`)
- Directories showing as both "not empty" and "no such file or directory"
- Affected both `/home/coder` and `/tmp` directories in the devpod

## Solution Applied
1. **Identified the problem**: Both npm and pnpm installs failed with TAR_ENTRY_ERROR and ENOTEMPTY errors
2. **Used clean location workaround**: Installed packages in `/tmp/npm-install-clean/` using pnpm with a separate store directory
3. **Replaced node_modules**: Moved the successfully installed `node_modules` back to the project

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
npx pnpm install --store-dir /tmp/pnpm-store

# 4. Replace corrupted node_modules in project
cd /home/coder/Research/moltbook-org/moltbook-frontend
find node_modules -delete 2>/dev/null || true  # Force delete corrupted entries
cp -r /tmp/npm-install-clean/node_modules /home/coder/Research/moltbook-org/moltbook-frontend/

# 5. Verify install works
npx pnpm install --store-dir /tmp/pnpm-store
```

## Verification
```bash
npx pnpm install --store-dir /tmp/pnpm-store
# Output: Packages: +711
#         Done in 4.6s using pnpm v10.28.2
#         All 711 packages successfully installed
```

## Status
- **RESOLVED**: pnpm install now works successfully
- **Note**: The build has a separate webpack configuration issue (Next.js 16 issuerLayer error) that is unrelated to filesystem corruption

## Related Files
- `FILESYSTEM_WORKAROUND.md` - Original workaround documentation (uses npm, but pnpm works better)
- `node_modules/` - Now functional (543MB, installed via pnpm)

## Long-term Recommendation
The Longhorn PVC should be recreated to prevent future filesystem corruption issues. When reinstalling, use the `/tmp` workaround directory with pnpm.
