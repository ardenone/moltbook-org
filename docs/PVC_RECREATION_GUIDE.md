# PVC Recreation Guide - Longhorn Filesystem Corruption Fix

**Date:** 2026-02-05
**Bead:** mo-9i6t
**Affected PVC:** `coder-jeda-codespace-home` (pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1)

---

## Problem Summary

The Longhorn PVC backing the devpod's `/home/coder` directory has filesystem corruption causing:
- `npm install` failures with `TAR_ENTRY_ERROR ENOENT` errors
- `ENOTEMPTY` errors during directory operations
- Files disappearing immediately after being written
- Inconsistent filesystem metadata

---

## Current Workaround (Functional)

The following workaround is currently in place and working:

### Automated Setup
A startup script at `~/.config/devpod-startup.sh` automatically mounts `node_modules` on tmpfs when the devpod starts. This is sourced from `~/.bashrc`.

### Manual Verification
```bash
# Check if node_modules is on tmpfs
mount | grep node_modules

# Expected output:
# tmpfs on /home/coder/Research/moltbook-org/moltbook-frontend/node_modules type tmpfs (...)
```

### Manual Setup (If automation fails)
```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend

# Mount tmpfs on node_modules
sudo mount -t tmpfs -o size=16G,nr_inodes=2M,nodev,nosuid tmpfs node_modules
sudo chown coder:coder node_modules

# Install dependencies using pnpm with /tmp store
pnpm install --store-dir /tmp/pnpm-store --force
```

### Build and Test
```bash
# Build works with tmpfs node_modules
npm run build

# Tests pass
npm test
```

---

## Permanent Solution: PVC Recreation

This is the recommended long-term fix to eliminate the filesystem corruption issue.

### Prerequisites

1. **Backup important data:**
   - Any uncommitted work in `/home/coder`
   - Configuration files not in git
   - SSH keys, credentials (if not externally managed)

2. **Choose a new storage class:**
   - `local-path` - Local SSD storage (RECOMMENDED - fastest, most reliable)
   - `nfs-synology` - Network storage (good for sharing across nodes)
   - `proxmox-local-lvm` - Proxmox LVM storage (if available)
   - `longhorn` - NOT RECOMMENDED (same issues may recur)

3. **Note: Git repositories can be re-cloned**, so no need to backup those specifically.

### Step-by-Step Procedure

#### Step 1: Document Current Devpod Configuration

```bash
# Export devpod configuration
kubectl get pod -n devpod -o wide | grep coder-jeda
kubectl get pvc coder-jeda-codespace-home -n devpod -o yaml > /tmp/coder-jeda-pvc-backup.yaml

# Note the storage class and size
kubectl get pvc coder-jeda-codespace-home -n devpod
```

#### Step 2: Stop and Delete Devpod

```bash
# Delete the devpod deployment (this will NOT delete the PVC)
kubectl delete deployment coder-jeda-codespace -n devpod

# Wait for pod to terminate
kubectl wait --for=delete pod -l app.kubernetes.io/instance=coder-jeda-codespace -n devpod --timeout=60s
```

#### Step 3: Delete the Old PVC

**WARNING: This will permanently delete all data on the PVC. Ensure you have backups!**

```bash
# Delete the PVC (this triggers Longhorn to delete the volume)
kubectl delete pvc coder-jeda-codespace-home -n devpod

# Wait for PVC to be deleted
kubectl wait --for=delete pvc coder-jeda-codespace-home -n devpod --timeout=120s
```

#### Step 4: Verify Longhorn Volume Cleanup

```bash
# Verify the Longhorn volume is deleted
kubectl get volumes.longhorn.io -n longhorn-system | grep pvc-8260aa67

# Expected: No output (volume is deleted)
```

#### Step 5: Create New PVC with Different Storage Class

Create a new PVC manifest with the desired storage class:

```yaml
# coder-jeda-codespace-home-new.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: coder-jeda-codespace-home
  namespace: devpod
  labels:
    app.kubernetes.io/instance: coder-jeda-codespace
    app.kubernetes.io/managed-by: coder
    app.kubernetes.io/name: coder-workspace
    app.kubernetes.io/part-of: coder
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 60Gi
  storageClassName: local-path  # Changed from longhorn
  volumeMode: Filesystem
```

Apply the new PVC:

```bash
kubectl apply -f coder-jeda-codespace-home-new.yaml

# Wait for PVC to be bound
kubectl wait --for=condition=Bound pvc/coder-jeda-codespace-home -n devpod --timeout=120s
```

#### Step 6: Recreate Devpod

The devpod should automatically recreate and bind to the new PVC. If not, you may need to manually recreate the deployment or use the Coder dashboard.

#### Step 7: Verify New Filesystem

```bash
# Inside the new devpod, check the filesystem
df -h /home/coder

# Verify it's using the new storage class
mount | grep "/home/coder"

# Expected: /dev/sdX or /dev/mapper/... (NOT longhorn)
```

#### Step 8: Clone Repositories and Install Dependencies

```bash
# Clone repositories
cd /home/coder/Research
git clone git@github.com:your-org/moltbook-org.git

cd moltbook-org/moltbook-frontend

# Install dependencies (should work without workarounds now)
pnpm install

# Verify build works
npm run build
npm test
```

---

## Alternative: Manual PVC Migration (Data Preservation)

If you need to preserve data on the corrupted PVC:

### Option A: Use rsync to Transfer Data

```bash
# 1. Create new PVC (see Step 5 above)
# 2. Attach both PVCs to a temporary pod
# 3. Use rsync to transfer data
rsync -av /old-pvc-mount/ /new-pvc-mount/

# 4. Detach old PVC, verify new PVC has data
# 5. Point devpod to new PVC
```

### Option B: Longhorn Snapshot and Clone

```bash
# 1. Create a snapshot of the corrupted volume
kubectl get volumes.longhorn.io -n longhorn-system
# Use Longhorn UI or API to create snapshot

# 2. Create a new volume from snapshot
# 3. Expand/contract the new volume (may force data migration)
# 4. Replace PVC with new volume

# Note: This may NOT fix filesystem corruption if the issue is in the snapshot
```

---

## Storage Class Comparison

| Storage Class | Speed | Reliability | Persistence | Recommended |
|--------------|-------|-------------|-------------|-------------|
| `local-path` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Node-local | ✅ YES |
| `nfs-synology` | ⭐⭐⭐ | ⭐⭐⭐⭐ | Network | ⚠️ Maybe |
| `proxmox-local-lvm` | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Node-local | ⚠️ Maybe |
| `longhorn` | ⭐⭐⭐ | ⭐⭐ | Replicated | ❌ NO (corruption) |

---

## Verification Tests

After recreating the PVC, run these tests to verify the filesystem is healthy:

```bash
# Test 1: Directory operations
cd /tmp
mkdir -p test-dir/subdir
rmdir test-dir/subdir
rmdir test-dir
echo "✓ Directory operations: OK"

# Test 2: File operations
echo "test" > test-file
cat test-file
rm test-file
echo "✓ File operations: OK"

# Test 3: npm install (the original failing operation)
cd /home/coder/Research/moltbook-org/moltbook-frontend
rm -rf node_modules package-lock.json
npm install
echo "✓ npm install: OK"

# Test 4: npm build
npm run build
echo "✓ npm build: OK"
```

---

## Troubleshooting

### Issue: PVC stuck in Terminating state

```bash
# Force delete PVC
kubectl patch pvc coder-jeda-codespace-home -n devpod -p '{"metadata":{"finalizers":null}}'
kubectl delete pvc coder-jeda-codespace-home -n devpod --force --grace-period=0
```

### Issue: Longhorn volume stuck

```bash
# Get the volume name
kubectl get volumes.longhorn.io -n longhorn-system

# Delete the volume
kubectl delete volume pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1 -n longhorn-system --force
```

### Issue: Devpod won't start with new PVC

```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/instance=coder-jeda-codespace -n devpod

# Check pod logs
kubectl logs -l app.kubernetes.io/instance=coder-jeda-codespace -n devpod

# Common issue: Wrong permissions on new PVC
# Fix: The PVC should be automatically initialized by the devpod
```

---

## Related Documentation

- `FILESYSTEM_WORKAROUND.md` - Temporary workaround documentation
- `DEVPOD_FILESYSTEM_ANALYSIS.md` - Detailed analysis of the corruption issue
- `BLOCKER_MO_1RP9_FILESYSTEM_SUMMARY.md` - Initial blocker analysis
- `NPM_FILESYSTEM_FIX_SUMMARY_MO_Y72H.md` - Previous fix attempt

---

## Status

- [x] Issue identified and documented
- [x] Temporary workaround implemented (tmpfs node_modules)
- [x] Automated startup script created
- [ ] PVC recreation scheduled (waiting for user approval)
- [ ] Permanent fix verified

---

## Next Steps

1. **Coordinate with cluster admin** to schedule PVC recreation
2. **Choose target storage class** (recommend: `local-path`)
3. **Schedule maintenance window** (downtime required)
4. **Perform backup** of any critical data not in git
5. **Execute recreation procedure** (steps 1-8 above)
6. **Verify filesystem health** with npm install/build tests
7. **Remove tmpfs workaround** after successful recreation

---

**Last Updated:** 2026-02-05
**Contact:** Cluster admin for PVC recreation approval
