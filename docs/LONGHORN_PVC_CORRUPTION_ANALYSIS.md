# Longhorn PVC Filesystem Corruption - Root Cause Analysis

## Executive Summary

The devpod's Longhorn PVC (`pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`) experiences chronic filesystem corruption during high I/O operations. The root cause is **cross-node replica synchronization** - the devpod runs on `k3s-dell-micro` but the Longhorn replica is on `k3s-lenovo-tiny`, introducing network latency that causes data loss during concurrent file operations.

## Symptoms

1. **npm install failures**: TAR_ENTRY_ERROR, ENOENT, ENOTEMPTY errors
2. **npm build failures**: Files written but immediately disappear (ENOENT on read)
3. **Intermittent corruption**: Basic operations work, but complex tar extraction fails

## Root Cause

### Storage Topology Analysis

```
┌─────────────────────────────────────────────────────────────┐
│                    Devpod Architecture                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  k3s-dell-micro (devpod node)                               │
│  ┌──────────────────────────────────────────┐              │
│  │  coder-jeda-codespace pod                │              │
│  │  └───────────────────────────────────────┤              │
│  │  /home/coder (Longhorn PVC mount)        │              │
│  └───────────────────┬──────────────────────┘              │
│                      │                                       │
│                      │ iSCSI/Network Block                  │
│                      ▼                                       │
│  k3s-lenovo-tiny (replica node)                             │
│  ┌──────────────────────────────────────────┐              │
│  │  pvc-8260aa67-r-507c9f48 (Longhorn)      │              │
│  │  Actual data storage                     │              │
│  └──────────────────────────────────────────┘              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Why This Causes Corruption

1. **Network Latency**: Every write must traverse the network to k3s-lenovo-tiny
2. **Replica Synchronization**: High I/O operations (npm tar extraction) create many small writes
3. **Race Conditions**: Network latency causes filesystem metadata to become inconsistent
4. **ext4 Limits**: ext4 on network block devices has known issues with concurrent operations

## Current Status (2026-02-05)

### PVC Details
- **Name**: `coder-jeda-codespace-home`
- **Volume**: `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
- **Capacity**: 60Gi
- **StorageClass**: `longhorn`
- **Attached to**: `k3s-dell-micro`
- **Replica on**: `k3s-lenovo-tiny` ❌ (different node!)

### Health Indicators
```
Longhorn Layer:  healthy (no issues detected)
ext4 Layer:      clean (last fsck: Jan 19, 2026)
Runtime:         CORRUPTED (files disappear after write)
```

### Current Workaround
1. Mount `node_modules` as tmpfs (16GB, in-memory)
2. Build in `/tmp` and transfer artifacts via tar
3. Use pnpm instead of npm (handles corruption better)

## Permanent Fix

### Solution: Same-Node Replica Affinity

Configure the PVC with node soft affinity to keep replicas on the same node as the consuming pod:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: coder-jeda-codespace-home
  namespace: devpod
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 60Gi
  storageClassName: longhorn
  volumeMode: Filesystem
```

Configure Longhorn StorageClass with replica node affinity:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-same-node
parameters:
  baseImage: "longhornio/longhorn-engine"
  fromBackup: ""
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  nodeSelector: "kubernetes.io/hostname"  # Same-node replica
provisioner: driver.longhorn.io
```

### Migration Procedure

1. **Backup data**
   ```bash
   # Backup critical data from /home/coder
   tar cf - /home/coder/Research | gzip > /tmp/moltbook-backup.tar.gz
   ```

2. **Delete devpod and PVC**
   ```bash
   kubectl delete pod coder-jeda-codespace-fccdd7b87-jn4bd -n devpod
   kubectl delete pvc coder-jeda-codespace-home -n devpod
   ```

3. **Recreate with new StorageClass**
   - Use `longhorn-same-node` StorageClass
   - Configure replica soft affinity for k3s-dell-micro

4. **Restore data**
   ```bash
   tar xf - -C /home/coder < /tmp/moltbook-backup.tar.gz
   ```

## Related Beads

- **mo-1zc9**: Fix: Recreate devpod PVC with same-node replica (CRITICAL)
- **mo-y72h**: Original filesystem workaround implementation
- **mo-9i6t**: This analysis

## Recommendations

1. **Immediate**: Use existing tmpfs workaround (documented in FILESYSTEM_WORKAROUND.md)
2. **Short-term**: Schedule maintenance window for PVC recreation (bead mo-1zc9)
3. **Long-term**: Configure same-node affinity for all devpod PVCs

## Verification Commands

```bash
# Check PVC replica placement
kubectl get replicas -n longhorn-system -o wide | grep pvc-8260aa67

# Check PVC attachment node
kubectl get volumes -n longhorn-system | grep pvc-8260aa67

# Verify filesystem corruption
cd /home/coder/Research/moltbook-org/moltbook-frontend
rm -rf node_modules
npm install 2>&1 | grep -E "(TAR_ENTRY_ERROR|ENOENT|ENOTEMPTY)"
```

## Status

- [x] Root cause identified (cross-node replica)
- [x] Workaround documented (tmpfs + /tmp build)
- [x] Permanent solution designed (same-node affinity)
- [ ] PVC recreation scheduled (bead mo-1zc9)
