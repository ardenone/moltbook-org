# Devpod Filesystem Corruption - Workaround Documentation

## Issue Summary (2026-02-05)

The devpod's Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has severe filesystem corruption:
- Files written immediately disappear
- `npm install` fails with `TAR_ENTRY_ERROR ENOENT` errors
- `pnpm install` fails with `ERR_PNPM_ENOENT` during file copy
- Even tmpfs mounts are affected due to corrupted source files in pnpm store

## Root Cause

The ext4 filesystem on the Longhorn block device is experiencing data loss:
1. Longhorn replica synchronization issues
2. Network/storage layer problems between devpod and Longhorn volume
3. Filesystem layer not properly flushing writes to stable storage

## PVC Details

- **PVC Name**: `coder-jeda-codespace-home`
- **Volume**: `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Capacity**: 60Gi
- **StorageClass**: `longhorn`
- **Node**: `k3s-dell-micro`
- **Status**: CRITICAL - Filesystem corrupted

## Current Solution (2026-02-05)

### Prerequisites
- pnpm is already installed: `/home/coder/.local/share/pnpm/pnpm`
- node_modules should be on tmpfs mount

### Setup Instructions (Run each time devpod restarts)

```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend

# 1. Mount tmpfs on node_modules (if not already mounted)
if ! mount | grep -q "node_modules type tmpfs"; then
    sudo mount -t tmpfs -o size=16G,nr_inodes=2M,nodev,nosuid tmpfs node_modules
    sudo chown coder:coder node_modules
fi

# 2. Install dependencies using pnpm with clean store
export PATH="/home/coder/.local/share/pnpm:$PATH"
pnpm install --force --shamefully-hoist --store-dir=/tmp/pnpm-store-clean

# 3. Build and test
pnpm run build
pnpm run test
```

### Important Notes

1. **node_modules on tmpfs is NOT persistent** - will be lost on pod restart
2. **Always use pnpm** - npm does not work with this project
3. **Build script updated to use pnpm** - see package.json
4. **Turbopack enabled** - bypasses webpack issuerLayer errors

## Build Configuration Changes

### package.json
```json
"scripts": {
  "build": "NODE_OPTIONS='--max-old-space-size=4096' pnpm run build:next",
  "build:next": "pnpm exec next build --turbopack"
}
```

### next.config.js
```javascript
// Using Turbopack to avoid webpack issuerLayer errors
turbopack: {
  root: __dirname,
}
```

## Long-term Solutions

### Option 1: Recreate Devpod with New PVC (Recommended)

Request cluster admin to:
1. Delete the current devpod
2. Delete the PVC `coder-jeda-codespace-home`
3. Create a new devpod with a fresh PVC

**Impact:**
- Requires backing up important data from `/home/coder`
- All data in home directory will be lost
- Takes time to recreate and configure

### Option 2: Schedule PVC Maintenance

The Longhorn volume may need:
- Replica resynchronization
- Snapshot rollback to a known good state
- Volume expansion/contraction to force data migration

### Option 3: Use Persistent tmpfs (Current Workaround)

- Mount node_modules on tmpfs at startup
- Reinstall dependencies on each pod restart
- Add to startup script or devpod configuration

## Verification

To verify the issue persists:
```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend
rm -rf node_modules package-lock.json
npm install 2>&1 | grep -E "(TAR_ENTRY_ERROR|ENOENT)"
```

Expected output if issue exists: Many `TAR_ENTRY_ERROR ENOENT` warnings.

## Status

- [x] Issue confirmed and documented
- [x] Temporary workaround implemented (tmpfs + pnpm)
- [x] Build configuration fixed (Turbopack + pnpm)
- [ ] Permanent fix scheduled (new PVC)

## Related Tasks

- Bead: mo-y72h - Infra: Devpod filesystem corruption blocking npm install
- Bead: mo-1nf - Code fixes that need verification after filesystem fix
