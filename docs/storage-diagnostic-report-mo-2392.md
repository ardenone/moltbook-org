# Devpod Storage Layer Diagnostic Report
**Bead:** mo-2392 - Blocker: Devpod storage layer corruption - overlayfs broken
**Date:** 2026-02-05
**Node:** k3s-dell-micro

## Executive Summary

The devpod's underlying Longhorn PVC shows **filesystem-level corruption symptoms** that affect npm/pnpm tar extraction operations. A temporary workaround using tmpfs mounts is currently in place and functional, but the root cause remains unresolved.

**Current Status:** WORKAROUND ACTIVE - Builds are functional via tmpfs

---

## Diagnostic Findings

### 1. PVC Information

| Property | Value |
|----------|-------|
| PVC Name | `coder-jeda-codespace-home` |
| PVC ID | `pvc-8260aa67-c0ae-49aa-a08e-54fbf98c32c1` |
| Storage Class | `longhorn` |
| Capacity | 60Gi |
| Used | 33Gi (56%) |
| Filesystem | ext4 |
| Node | k3s-dell-micro |
| Age | 16 days |

### 2. Filesystem Health

**Block Device Level (ext4):**
```
Filesystem state:         clean
Last mounted on:          Tue Feb  3 02:53:11 2026
Mount count:              11
Lifetime writes:          492 GB
```

The ext4 filesystem reports as "clean" at the block device level with no fsck errors.

### 3. Active Workaround - tmpfs Mounts

The following tmpfs mounts are **currently active** and bypass the Longhorn PVC:

| Directory | Mount Type | Size | Purpose |
|-----------|------------|------|---------|
| `/home/coder/Research/moltbook-org/moltbook-frontend/node_modules` | tmpfs | 16GB | npm dependencies |
| `/home/coder/Research/moltbook-org/moltbook-frontend/.next` | tmpfs | 8GB | Next.js build cache |

**Status:** Workaround is functional. Node modules populate correctly (36,180 files).

### 4. Available Storage Classes

| Storage Class | Provisioner | Expansion | Notes |
|---------------|-------------|-----------|-------|
| local-path (default) | rancher.io/local-path | No | Local node storage - FASTEST |
| longhorn | driver.longhorn.io | Yes | Distributed block storage - CURRENT |
| nfs-synology | synology-nfs | Yes | Network NFS - slower but persistent |
| proxmox-local-lvm | csi.proxmox.sinextra.dev | Yes | Proxmox LVM - good alternative |

### 5. Root Cause Analysis

**Primary Issue:** Longhorn PVC exhibits silent filesystem corruption affecting specific operations:

1. **ENOTEMPTY errors** on directory removal during npm install
2. **TAR_ENTRY_ERROR** during package extraction
3. **overlayfs mount failures** with "invalid argument"

**Why ext4 shows "clean" but operations fail:**
- The corruption is likely at the **overlayfs layer** (containerd snapshotter), not the block device
- The Longhorn block device may be healthy, but the containerd overlayfs layers on top have issues
- This explains why direct filesystem checks pass but tar/npm operations fail

**Contributing Factors:**
- High I/O during npm install with thousands of small files
- Deep overlayfs layer stack (25+ layers visible in mount output)
- Longhorn's network block storage over overlayfs compounds complexity

---

## Recommendations

### Option 1: Recreate Devpod with local-path Storage (RECOMMENDED)

**Pros:**
- Fastest performance (direct local SSD/NVMe)
- No network storage overhead
- Simpler storage stack (no overlayfs over network block device)

**Cons:**
- Data not replicated across nodes
- Pod must be scheduled on specific node
- Requires devpod recreation

**Steps:**
1. Backup all data from current devpod
2. Delete current devpod and PVC
3. Modify devpod template to use `local-path` storage class
4. Restore data to new devpod

### Option 2: Keep Current Setup with tmpfs Workaround

**Pros:**
- No migration required
- Builds work correctly
- Longhorn replication for data safety

**Cons:**
- tmpfs mounts not persistent across pod restarts
- Manual setup required after each restart
- Does not fix underlying issue
- Memory pressure (16GB+8GB reserved)

### Option 3: Migrate to proxmox-local-lvm Storage

**Pros:**
- Better performance than Longhorn (local LVM)
- Volume expansion supported
- More reliable than network block storage for high I/O

**Cons:**
- Requires data migration
- Devpod recreation needed
- Tied to Proxmox infrastructure

---

## Action Items

- [ ] **Decision needed:** Choose storage migration strategy
- [ ] Create migration plan if PVC recreation is approved
- [ ] Document tmpfs setup procedure for pod restarts
- [ ] Consider automating tmpfs mount via initContainer

---

## Scripts and Workarounds

### Current Workaround Script
- **Location:** `scripts/setup-frontend-tmpfs.sh`
- **Status:** Already committed (see git status)
- **Usage:** Run after pod restart to restore tmpfs mounts

### Health Check Script
- **Location:** `scripts/pvc-health-check.sh`
- **Status:** Available for diagnostics

---

## Related Beads

- mo-9i6t: Fix: Longhorn PVC filesystem corruption blocking npm installs
- mo-11q0: Blocker: Longhorn storage filesystem corruption preventing npm install

---

## Technical Details

### Mount Structure
```
/ (overlay, 25+ layers)
  ├─/home/coder (Longhorn ext4 PVC)
    ├─/home/coder/Research/moltbook-org/moltbook-frontend/node_modules (tmpfs)
    └─/home/coder/Research/moltbook-org/moltbook-frontend/.next (tmpfs)
```

### Containerd Snapshotter
- Type: overlayfs
- Layers: 25+ lower layers + 1 upper layer + work directory
- Location: `/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/`

### Longhorn Volume Status
- State: attached
- Robustness: healthy
- Frontend: blockdev
- Data Engine: v1
- Replicas: 1
