# Moltbook Deployment Path Decision

**Bead**: mo-1ts4
**Date**: 2026-02-05
**Status**: **DECIDED - PATH 2 (kubectl manual)**

## Executive Summary

After evaluating PATH 1 (ArgoCD GitOps via external ArgoCD) vs PATH 2 (kubectl manual), **PATH 2 is selected** as the deployment strategy for Moltbook.

**Key Findings:**
- External ArgoCD exists at `argocd-manager.ardenone.com` (health check returns "ok")
- External ArgoCD read-only token is EXPIRED (mo-dbl7) - blocking PATH 1
- Installing local ArgoCD is redundant with external instance available
- Both paths require cluster-admin action for namespace creation

**Decision Rationale:** PATH 2 unblocks deployment immediately while PATH 1 remains blocked on expired credentials. Can migrate to external ArgoCD GitOps later when credentials are resolved.

## Current State

| Resource | Status |
|----------|--------|
| External ArgoCD | **ONLINE** at argocd-manager.ardenone.com |
| Namespace `argocd` | Does NOT exist (local not installed) |
| Namespace `moltbook` | Does NOT exist |
| Devpod cluster-admin | NOT granted |
| Devpod namespace creation | NOT granted |

## PATH Comparison

### PATH 1: External ArgoCD GitOps (BLOCKED - Not Selected)

**What it provides:**
- Automated GitOps deployment via external ArgoCD at argocd-manager.ardenone.com
- Self-healing and sync capabilities
- Long-term maintainability

**Cluster admin action required:**
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

**This creates:**
1. `namespace-creator` ClusterRole
2. `devpod-namespace-creator` ClusterRoleBinding
3. `moltbook` namespace

**After cluster admin applies, devpod would:**
1. Obtain valid ArgoCD credentials for argocd-manager.ardenone.com
2. Create Application on external ArgoCD targeting moltbook-org repository
3. ArgoCD syncs manifests automatically

**BLOCKERS:**
- ❌ ArgoCD read-only token expired (mo-dbl7)
- ❌ Cannot create Application without valid credentials
- ⚠️ Requires external ArgoCD admin access

**Advantages:**
- ✅ GitOps automation (auto-sync on git push)
- ✅ Drift detection and self-healing
- ✅ Standard deployment pattern for the organization

### PATH 1b: Local ArgoCD Installation (NOT SELECTED - Redundant)

**Why not selected:**
- External ArgoCD already exists at argocd-manager.ardenone.com
- Installing local ArgoCD is redundant
- Additional cluster-admin overhead
- Not the intended architecture per ARGOCD_ARCHITECTURE_ANALYSIS.md

### PATH 2: kubectl Manual (SELECTED)

**What it provides:**
- Direct kubectl deployment
- Immediate deployment capability
- Migration path to external ArgoCD later

**Cluster admin action required:**
```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

**This creates:**
1. `namespace-creator` ClusterRole (namespace permissions only)
2. `devpod-namespace-creator` ClusterRoleBinding
3. `moltbook` namespace

**After cluster admin applies, devpod runs:**
```bash
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

**Advantages:**
- Single cluster-admin action
- Faster time to deployment
- Uses existing infrastructure patterns
- Simpler troubleshooting
- Can migrate to external ArgoCD later

## Decision Rationale

| Factor | PATH 1 (Local ArgoCD) | PATH 2 (kubectl) | Winner |
|--------|----------------|------------------|---------|
| External ArgoCD exists | Redundant | Uses existing | PATH 2 |
| Cluster admin actions | 2 steps | 1 step | PATH 2 |
| Time to first deploy | Longer | Immediate | PATH 2 |
| GitOps eventually | Yes (via migration) | Yes (via migration) | Tie |
| Setup complexity | High | Low | PATH 2 |
| Infrastructure reuse | No | Yes (external ArgoCD) | PATH 2 |

**PATH 2 is recommended** because:
1. External ArgoCD already exists - local installation is redundant
2. Single cluster-admin action reduces coordination overhead
3. Faster time to deployment - removes ArgoCD from critical path
4. Migration path exists - can adopt external ArgoCD GitOps when ready
5. Simpler troubleshooting during initial deployment

## Implementation: PATH 2

### Step 1: Cluster Admin Action (BLOCKER)

Apply the namespace setup manifest:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
- `namespace-creator` ClusterRole
- `devpod-namespace-creator` ClusterRoleBinding
- `moltbook` namespace

### Step 2: Deploy Moltbook (Devpod)

After cluster admin action:

```bash
# Verify namespace exists
kubectl get namespace moltbook

# Deploy all resources
kubectl apply -k k8s/

# Verify deployment
kubectl get pods -n moltbook
kubectl get ingressroutes -n moltbook
```

### Step 3: Verify Services

Expected endpoints:
- `https://moltbook.ardenone.com` (frontend)
- `https://api-moltbook.ardenone.com` (API)

## Future GitOps Migration

Once Moltbook is deployed, it can be migrated to the external ArgoCD at `argocd-manager.ardenone.com`:

1. Register ardenone-cluster with external ArgoCD (if not already)
2. Create ApplicationSet for moltbook-org repository
3. Enable sync for `k8s/` directory to `moltbook` namespace
4. Enable auto-sync for ongoing GitOps

## Next Steps (Cluster Admin)

1. Apply the RBAC manifest:
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
   ```

2. Verify the resources were created:
   ```bash
   kubectl get clusterrole namespace-creator
   kubectl get clusterrolebinding devpod-namespace-creator
   kubectl get namespace moltbook
   ```

3. Notify the devpod operator that permissions are granted

## Related Files

- `k8s/NAMESPACE_SETUP_REQUEST.yml` - RBAC + namespace manifest (cluster-admin to apply)
- `k8s/kustomization.yml` - Main deployment manifest
- `k8s/argocd-application.yml` - Future GitOps configuration
- `k8s/ARGOCD_INSTALL_REQUEST.yml` - NOT USED - local ArgoCD path declined
