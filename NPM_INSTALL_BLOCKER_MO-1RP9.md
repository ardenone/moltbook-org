# NPM Install Blocker - mo-1rp9

## Summary

The devpod's underlying Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) has filesystem issues causing npm install to fail repeatedly with ENOENT errors when creating directories in node_modules.

## Root Cause Analysis

### Symptoms
- `TAR_ENTRY_ERROR ENOENT` errors during npm install
- `ENOTEMPTY: directory not empty, rmdir` errors during cleanup
- Directories appear to be created but cannot be found by npm during tar extraction
- Cannot remove certain directories (Directory not empty errors)

### Affected Volume
- **PVC**: `coder-jeda-codespace-home` in namespace `devpod`
- **Longhorn Volume**: `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Mount Point**: `/home/coder` (ext4)
- **Status**: Attached and "healthy" according to Longhorn, but filesystem is corrupted

### Technical Details

The issue is at the **ext4 filesystem layer on the Longhorn volume**. The Longhorn engine reports the volume as "healthy" and "robust", but the ext4 filesystem has consistency issues that prevent:

1. **Directory creation during tar extraction** - npm's tar extractor creates directories but then cannot stat them
2. **Directory removal** - `rm -rf` fails with "Directory not empty" on directories that should be removable
3. **File operations** - Copy operations (cp, rsync) fail to properly transfer directory structures

### Confirmed Workaround

Installing to `/tmp` (different filesystem) works correctly:
```bash
cd /tmp && mkdir moltbook-install && cd moltbook-install
cp /path/to/project/package*.json .
npm install --legacy-peer-deps
```

However, **copying the installed node_modules back to the Longhorn PVC fails** due to the same filesystem issues.

## Resolution Required (Cluster Admin Action)

### Option 1: Schedule Filesystem Check and Repair (Recommended)

The devpod needs to be temporarily recreated to allow filesystem repair:

1. **Delete the current devpod** to release the PVC:
   ```bash
   kubectl delete deployment coder-jeda-codespace -n devpod
   ```

2. **Wait for the pod to terminate** and PVC to be released

3. **Run filesystem check on the Longhorn volume** via Longhorn engine or host node:
   ```bash
   # On the node where the volume is attached (k3s-dell-micro)
   fsck.ext4 -y /dev/longhorn/pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1
   ```

4. **Recreate the devpod** - the PVC will automatically reattach

### Option 2: Create New PVC and Migrate Data

If the filesystem is beyond repair:

1. Create a new PVC for the devpod
2. Copy data from the old PVC to the new one (at the block level or via tar)
3. Update the devpod deployment to use the new PVC
4. Delete the old PVC after migration is complete

### Option 3: Increase Longhorn Volume Replicas

The volume currently has only 1 replica. Increasing to 2-3 replicas may help with data consistency and provide recovery options:

```yaml
# Longhorn Volume spec update
numberOfReplicas: 3
```

## Temporary Workaround for Development

While waiting for cluster admin resolution, developers can:

1. **Work in /tmp directory** for npm operations:
   ```bash
   cd /tmp/moltbook-work
   cp -r ~/Research/moltbook-org/moltbook-frontend/* .
   npm install
   # Make changes...
   ```

2. **Use npm install with --legacy-peer-deps** to reduce complexity

3. **Accept the TAR_ENTRY_ERROR warnings** - npm may complete despite warnings

## Related Issues

- Bead ID: mo-1rp9
- PVC Age: 16 days (created 2026-01-19)
- Last Remount: 2026-02-03 02:39:43Z
- Node: k3s-dell-micro

## Verification Steps

After filesystem repair, verify with:

```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend
rm -rf node_modules package-lock.json
npm install --legacy-peer-deps
npm run build
```

Expected: Clean install without TAR_ENTRY_ERROR or ENOTEMPTY errors.
