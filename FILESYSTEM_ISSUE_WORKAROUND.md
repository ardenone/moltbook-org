# Devpod Filesystem Issue - npm install ENOENT Errors

## Issue Description

The devpod's Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) exhibits filesystem corruption symptoms:
- Files are written but immediately disappear
- npm install fails with repeated `TAR_ENTRY_ERROR ENOENT` errors
- Longhorn reports volume as "healthy" but ext4 filesystem is unstable

## Root Cause

The ext4 filesystem on top of the Longhorn block device is experiencing data loss. This is likely due to:
1. Longhorn replica synchronization issues
2. Network/storage layer problems between the devpod and the Longhorn volume
3. The filesystem layer is not properly flushing writes to stable storage

## Workaround

### Option 1: Use tmpfs for node_modules (Recommended for Development)

Since the issue affects persistent storage, use an in-memory filesystem for node_modules:

```bash
# Create a tmpfs mount for node_modules
sudo mkdir -p /mnt/node_modules-tmpfs
sudo mount -t tmpfs -o size=8G tmpfs /mnt/node_modules-tmpfs

# Symlink to project
cd /home/coder/Research/moltbook-org/moltbook-frontend
rm -rf node_modules
ln -s /mnt/node_modules-tmpfs node_modules

# Install dependencies
npm install
```

**Note**: node_modules will be lost on pod restart, but npm install will work.

### Option 2: Recreate Devpod with New PVC (Permanent Fix)

Request the cluster admin to:
1. Delete the current devpod
2. Delete the PVC `coder-jeda-codespace-home`
3. Create a new devpod with a fresh PVC

This will require:
- Backing up important data from `/home/coder`
- Recreating the devpod
- Restoring data

### Option 3: Schedule PVC Maintenance

The Longhorn volume may need:
- Replica resynchronization
- Snapshot rollback to a known good state
- Volume expansion/contraction to force data migration

## PVC Details

- **PVC Name**: `coder-jeda-codespace-home`
- **Volume**: `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Capacity**: 60Gi
- **StorageClass**: `longhorn`
- **Node**: `k3s-dell-micro`
- **Age**: 16 days

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
- [ ] Temporary workaround applied (tmpfs for node_modules)
- [ ] Permanent fix scheduled (new PVC)

## Related Tasks

- Bead: mo-1rp9 - Fix: Devpod filesystem issues preventing npm install
