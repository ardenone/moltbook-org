# PVC Migration Guide for Longhorn Filesystem Corruption

**Issue**: Bead mo-9i6t - Longhorn PVC filesystem corruption blocking npm installs
**Affected PVC**: `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` (coder-jeda-codespace-home)
**Date**: 2026-02-05

## Problem Summary

The Longhorn-backed PVC (`/home/coder` mount) experiences filesystem corruption that causes:
- `npm install` fails with `TAR_ENTRY_ERROR` and `ENOTEMPTY` errors
- Concurrent file operations during tar extraction fail
- Files written immediately disappear or become unreadable

### Root Cause Analysis

1. **Longhorn replica synchronization issues**: Multiple replicas may not be in sync
2. **Network filesystem latency**: Devpod to Longhorn engine network delays
3. **ext4 filesystem inconsistency**: The ext4 filesystem on the Longhorn block device has corruption

## Current Workaround (Functional)

### For Frontend Development

The project uses pnpm with `/tmp` store to avoid the corrupted filesystem:

```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend
npx pnpm install --store-dir /tmp/pnpm-store
npm run build
```

### Automated Scripts

1. **Health Check**: `./scripts/pvc-health-check.sh` - Diagnoses PVC issues
2. **Install Workaround**: `./scripts/npm-install-workaround.sh` - Installs via /tmp
3. **pnpm Helper**: `./moltbook-frontend/scripts/pnpm-helper.sh` - pnpm utilities

### Why This Works

- `/tmp` is on a different filesystem (overlay/tmpfs)
- Longhorn PVC corruption doesn't affect `/tmp`
- pnpm's content-addressable store works well with this approach

## Long-Term Solutions

### Option 1: Migrate to local-path Storage (Recommended)

**Pros**:
- Fast local SSD storage
- No network latency
- Simple to set up
- Better performance for development

**Cons**:
- Not replicated (data loss if node fails)
- Pod must be on same node after recreation

**Steps**:
1. Backup all important data from `/home/coder`
2. Delete current devpod deployment
3. Delete the Longhorn PVC
4. Update devpod configuration to use `local-path` storage class
5. Create new devpod
6. Restore data from backup

### Option 2: Migrate to nfs-synology Storage

**Pros**:
- True network storage (accessible from any node)
- Persistent across pod recreations
- NAS has built-in redundancy

**Cons**:
- Network latency (slower than local storage)
- Depends on NAS availability

**Steps**:
1. Backup all important data from `/home/coder`
2. Create new PVC with `nfs-synology` storage class
3. Use `rsync` to migrate data to new PVC
4. Update devpod to use new PVC
5. Delete old Longhorn PVC

### Option 3: Migrate to proxmox-local-lvm Storage

**Pros**:
- Local LVM storage (fast)
- Managed by Proxmox
- Better than Longhorn for single-node setups

**Cons**:
- Requires Proxmox integration
- May need CSI driver configuration

## Storage Class Comparison

| Storage Class | Type | Speed | Replication | Use Case |
|--------------|------|-------|-------------|----------|
| **longhorn** | Network block storage | Medium | Yes (3 replicas) | Distributed workloads |
| **local-path** | Local storage | Fast | No | Single-node dev/test |
| **nfs-synology** | NFS network storage | Slow | Yes (NAS RAID) | Shared storage |
| **proxmox-local-lvm** | Local LVM | Fast | No | Proxmox VMs |

## Migration Procedure

### Preparation

```bash
# 1. Check current PVC usage
du -sh /home/coder/*

# 2. Identify important directories to backup
# Usually: ~/.ssh, ~/.gitconfig, project directories

# 3. Create backup on external storage
tar czf /tmp/devpod-backup-$(date +%Y%m%d).tar.gz \
    ~/.ssh \
    ~/.gitconfig \
    ~/.local \
    /home/coder/Research \
    /home/coder/.kube
```

### For Kubernetes Administrator

If you have cluster admin access, follow these steps:

#### 1. Identify Resources

```bash
# Get PVC details
kubectl get pvc coder-jeda-codespace-home -o yaml

# Get devpod deployment
kubectl get deployments -l devpod

# Get storage classes
kubectl get storageclass
```

#### 2. Backup Data (from within devpod)

```bash
# Create backup on external storage (e.g., nfs-synology PVC)
kubectl exec -it <devpod-pod> -- tar czf /backup/devpod-home-backup.tar.gz -C /home/coder .

# Or copy to local machine
kubectl cp <devpod-pod>:/home/coder ./devpod-backup
```

#### 3. Delete and Recreate

```bash
# Scale down devpod to 0
kubectl scale deployment <devpod-deployment> --replicas=0

# Delete the PVC (data will be lost!)
kubectl delete pvc coder-jeda-codespace-home

# Create new PVC with different storage class
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: coder-jeda-codespace-home
  namespace: devpod
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # or nfs-synology
  resources:
    requests:
      storage: 60Gi
EOF

# Restore devpod deployment (it will use new PVC)
kubectl scale deployment <devpod-deployment> --replicas=1

# Restore data (from within new devpod)
cd /home/coder
tar xzf /backup/devpod-home-backup.tar.gz
```

## Testing After Migration

```bash
# Run the health check script
cd /home/coder/Research/moltbook-org
./scripts/pvc-health-check.sh

# Test npm install without workarounds
cd moltbook-frontend
rm -rf node_modules
npm install  # Should work without errors!

# Test build
npm run build
```

## Rollback Procedure

If migration fails:

```bash
# 1. Scale down devpod
kubectl scale deployment <devpod-deployment> --replicas=0

# 2. Delete new PVC
kubectl delete pvc coder-jeda-codespace-home

# 3. Recreate Longhorn PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: coder-jeda-codespace-home
  namespace: devpod
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 60Gi
EOF

# 4. Restore data from backup
# 5. Scale up devpod
kubectl scale deployment <devpod-deployment> --replicas=1
```

## Prevention

To prevent future filesystem corruption:

1. **Monitor Longhorn volume health**: Set up alerts for replica synchronization issues
2. **Regular snapshots**: Create automated snapshots of the PVC
3. **Use appropriate storage**: local-path for development, Longhorn for production
4. **Monitor filesystem**: Run `dmesg | grep -i error` regularly

## Related Documentation

- `moltbook-frontend/NPM_FILESYSTEM_FIX_SUMMARY_MO_Y72H.md` - Original fix summary
- `moltbook-frontend/FILESYSTEM_WORKAROUND.md` - Workaround documentation
- `scripts/npm-install-workaround.sh` - Automated install workaround
- `scripts/pvc-health-check.sh` - Health check script

## Status

- [x] Issue identified and documented
- [x] Workaround implemented (pnpm with /tmp store)
- [x] Health check script created
- [x] Migration guide documented
- [ ] Migration to new storage class scheduled
- [ ] Migration completed and verified
