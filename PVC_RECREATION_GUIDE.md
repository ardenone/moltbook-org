# PVC Recreation Guide - Devpod Filesystem Fix

**Bead:** mo-9i6t
**PVC:** `coder-jeda-codespace-home`
**Volume:** `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1`
**Namespace:** `devpod`

## Summary

This guide documents the procedure to recreate the devpod's Longhorn PVC to permanently fix the filesystem corruption that blocks npm install operations.

## Current Status

- **Temporary Workaround:** ✅ Implemented (tmpfs on node_modules)
- **npm install:** ✅ Working (via tmpfs + pnpm)
- **Build:** ✅ Working (via Turbopack)
- **Permanent Fix:** ❌ Pending (PVC recreation required)

## Root Cause

The ext4 filesystem on the Longhorn PVC has corruption at the filesystem layer:
- Longhorn block device reports `healthy`
- ext4 filesystem has inode/directory entry corruption
- Files disappear immediately after being written
- npm tar extraction fails with `ENOENT`/`ENOTEMPTY` errors

## Option 1: Recreate Devpod with New PVC (Recommended)

### Pre-Migration Checklist

1. **Backup critical data** (anything not in git):
   ```bash
   # Check for uncommitted changes
   cd /home/coder/Research/moltbook-org
   git status

   # Check for important local files
   ls -la ~/.config/
   ls -la ~/.local/
   ```

2. **Document devpod configuration**:
   - Environment variables
   - SSH keys
   - Tool configurations
   - VS Code settings

### Migration Steps

**Step 1: Delete the devpod deployment**
```bash
kubectl delete deployment coder-jeda-codespace -n devpod
```

**Step 2: Delete the corrupted PVC**
```bash
kubectl delete pvc coder-jeda-codespace-home -n devpod
```

**Step 3: Verify PVC is deleted**
```bash
kubectl get pvc -n devpod
# Should show no PVC for coder-jeda-codespace-home
```

**Step 4: Recreate devpod**
- Via Devpod CLI: `devpod up coder-jeda-codespace`
- Via ArgoCD: The deployment will be auto-recreated
- Via Coder: The workspace will be auto-provisioned

**Step 5: Verify new PVC**
```bash
kubectl get pvc -n devpod
# Should show new PVC with different UID
```

**Step 6: Re-clone repositories and install dependencies**
```bash
cd /home/coder/Research
git clone <repo-url> moltbook-org
cd moltbook-org/moltbook-frontend
pnpm install
```

### Rollback (if needed)

If the new PVC also has issues:
```bash
# Check Longhorn system logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100

# Check node disk health
kubectl describe node k3s-dell-micro
```

## Option 2: Migrate to Different Storage Class

If Longhorn continues to have issues, migrate to a different storage class:

### Available Storage Classes

```bash
kubectl get storageclass
```

### Migration Procedure

**Step 1: Create new PVC with different storage class**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: coder-jeda-codespace-home-v2
  namespace: devpod
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # or other available class
  resources:
    requests:
      storage: 60Gi
```

**Step 2: Migrate data** (if any critical data exists)
```bash
# Create temporary pod with both PVCs mounted
# Copy data from old to new
```

**Step 3: Update deployment to use new PVC**
```yaml
volumes:
  - name: home
    persistentVolumeClaim:
      claimName: coder-jeda-codespace-home-v2  # New PVC
```

**Step 4: Delete old PVC**
```bash
kubectl delete pvc coder-jeda-codespace-home -n devpod
```

## Option 3: Increase Longhorn Replicas (Preventative)

To prevent future corruption, increase replica count:

```bash
kubectl patch volume pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1 \
  -n longhorn-system \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/numberOfReplicas", "value": 3}]'
```

**Note:** This requires recreating the volume, so it's better to do during PVC recreation.

## Post-Migration Verification

After recreation, verify the fix:

```bash
cd /home/coder/Research/moltbook-org/moltbook-frontend

# Remove tmpfs workaround
sudo umount node_modules
rm -rf node_modules

# Test npm install directly on PVC
pnpm install

# Verify no errors
echo "Install completed successfully!"

# Test build
pnpm run build
```

## Temporary Workaround (Pre-Migration)

While waiting for PVC recreation, use the automated workaround:

```bash
# Run the setup script
bash ~/.config/devpod-filesystem-fix/setup-node_modules-tmpfs.sh

# Or manually mount tmpfs
cd /home/coder/Research/moltbook-org/moltbook-frontend
sudo mount -t tmpfs -o size=16G,nr_inodes=2M,nodev,nosuid tmpfs node_modules
sudo chown coder:coder node_modules
pnpm install --force --shamefully-hoist --store-dir=/tmp/pnpm-store-clean
```

## Estimated Downtime

- **PVC deletion:** < 1 minute
- **New PVC provisioning:** 1-2 minutes
- **Devpod startup:** 2-3 minutes
- **Repository cloning:** 5-10 minutes
- **Dependencies installation:** 2-5 minutes

**Total:** ~15-20 minutes

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss | Medium | High | Ensure all code is committed to git |
| New PVC also corrupted | Low | High | Use different storage class |
| Extended downtime | Low | Medium | Schedule during low-usage hours |
| Configuration lost | Low | Medium | Document settings before migration |

## Decision Matrix

| Option | Time Required | Data Loss Risk | Permanence |
|--------|--------------|----------------|------------|
| Recreate PVC | 20 min | Medium | ✅ Permanent |
| Migrate storage class | 30 min | Low | ✅ Permanent |
| Keep tmpfs workaround | 0 min | None | ❌ Temporary |

## Recommendation

**Recreate the PVC during a planned maintenance window.** The tmpfs workaround is functional but not a long-term solution. A fresh PVC will eliminate all filesystem corruption issues and restore normal operations.

## Related Issues

- Bead mo-1rp9: Original filesystem corruption issue
- Bead mo-y72h: Devpod filesystem corruption blocking npm install
- Bead mo-9i6t: This fix implementation
