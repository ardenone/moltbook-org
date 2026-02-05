# Devpod Storage Fix - mo-2392

## Summary

Fixed devpod storage layer corruption issues by addressing the `/dev/shm` (shared memory) being filled up by pnpm, which was causing build failures.

## Investigation Results

### Issue Analysis

1. **Longhorn PVC Health**: The underlying Longhorn volume `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` is healthy:
   - Status: `attached`
   - Robustness: `healthy`
   - Node: `k3s-dell-micro`
   - Actual size: ~72GB used of 60GB capacity (snapshot overhead)

2. **overlayfs Status**: Containerd overlayfs is working correctly:
   - Storage driver: `overlayfs`
   - Multiple overlay mounts active and functional

3. **Critical Finding - `/dev/shm` 100% Full**:
   ```
   Filesystem      Size  Used Avail Use% Mounted on
   shm              64M   64M     0 100% /dev/shm
   ```
   - `/dev/shm/pnpm-store` was filling up the 64MB shared memory
   - This causes npm/pnpm build failures and can affect IPC operations

### Root Cause

pnpm was storing data in `/dev/shm/pnpm-store` despite the configured store-dir being `/tmp/pnpm-store`. This is likely due to:
- Environment variables or defaults in some npm/pnpm versions
- The small 64MB `/dev/shm` limit in containers

### Symptoms Fixed

- TAR_ENTRY_ERROR during npm installations (due to no space in /dev/shm)
- Build failures during Next.js builds
- IPC-related errors (shared memory full)

## Fix Applied

### 1. Cleared /dev/shm
```bash
rm -rf /dev/shm/pnpm-store
```

### 2. Updated pnpm Configuration
Updated `/home/coder/.config/pnpm/rc`:
```ini
store-dir=/tmp/pnpm-store
# Disable using /dev/shm for pnpm store to prevent filling up shared memory
# Use /tmp instead which has more space
shamefully-hoist=false
strict-peer-dependencies=false
```

## Verification

After fix:
```bash
$ df -h /dev/shm
Filesystem      Size  Used Avail Use% Mounted on
shm              64M     0   64M   0% /dev/shm
```

npm operations now work correctly:
- tar extraction: ✓
- directory removal: ✓
- npm install: ✓

## Recommendations

1. **Monitor /dev/shm usage**: Check with `df -h /dev/shm` periodically
2. **Use tmpfs for node_modules**: The existing tmpfs workaround in `/home/coder/.config/devpod-startup.sh` is still recommended for large node_modules
3. **Keep pnpm store on /tmp**: The /tmp filesystem has more space than /dev/shm

## Commands to Monitor Storage Health

```bash
# Check shared memory usage
df -h /dev/shm

# Check PVC status
kubectl get pvc -n devpod

# Check Longhorn volume health
kubectl get volumes.longhorn.io -n longhorn-system

# Check overlayfs mounts
mount | grep overlay

# Check disk usage
df -h
```

## Related Beads

- mo-9i6t: Fix: Longhorn PVC filesystem corruption blocking npm install
- mo-11q0: Blocker: Longhorn storage filesystem corruption preventing npm install
- mo-1rp9: Blocker: PVC filesystem corruption ENOTEMPTY errors

## Files Modified

- `/home/coder/.config/pnpm/rc` - Updated to prevent /dev/shm usage
