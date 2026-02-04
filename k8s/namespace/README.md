# Moltbook Namespace Setup

This directory contains manifests for setting up the Moltbook namespace in the ardenone-cluster.

## Current Status (2026-02-04 19:25 UTC)

**BLOCKED - Awaiting Cluster Admin Action**

- Namespace `moltbook`: **Does NOT exist** (verified at 2026-02-04 19:19 UTC)
- RBAC `devpod-namespace-creator`: **NOT applied**
- RBAC `namespace-creator` ClusterRole: **Does NOT exist**
- RBAC `devpod-namespace-creator` ClusterRoleBinding: **Does NOT exist**
- Current blocker bead: **mo-2mxj** (BLOCKER: Cluster Admin needed - Create moltbook namespace)
- Related beads: mo-3flx, mo-drj, mo-ddt3, mo-7k95, mo-2byg, mo-y1f5 (multiple duplicate blockers)
- Helper script: `../setup-namespace.sh` (run from k8s directory)
- Task bead: **mo-cx8** (Deploy: Apply Moltbook manifests to ardenone-cluster)

**Note:** Multiple duplicate blocker beads exist for this same issue. The most recent is mo-2mxj (created 2026-02-04 by mo-cx8).

### Why This is Blocked

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) does not have cluster-scoped permissions to:
1. Create namespaces (cluster-scoped resource)
2. Create ClusterRole/ClusterRoleBinding (cluster-scoped resources)

This is an intentional security boundary. Namespace creation requires cluster-admin privileges.

## Prerequisites

This setup requires **cluster-admin** privileges to create namespaces and apply RBAC.

## Cluster Admin Action Required

**To unblock moltbook deployment, a cluster admin must run:**

```bash
# From the k8s/namespace directory
cd /home/coder/Research/moltbook-org/k8s/namespace

# Option 1: Create namespace only (minimal, recommended)
kubectl apply -f moltbook-namespace.yml

# Option 2: Grant devpod namespace creation permissions AND create namespace
kubectl apply -f devpod-namespace-creator-rbac.yml
kubectl apply -f moltbook-namespace.yml
```

**Verification:**
```bash
kubectl get namespace moltbook
```

After the namespace is created, the devpod can deploy resources within it using the namespace-scoped RBAC in `moltbook-rbac.yml`.

## Setup Instructions

### Option 1: Create Namespace Only (Quickest)

If you just want to create the namespace without granting devpod permanent namespace creation permissions:

```bash
# Run as cluster-admin
kubectl create namespace moltbook
```

Or apply the manifest:

```bash
kubectl apply -f moltbook-namespace.yml
```

### Option 2: Grant Namespace Creation Permissions (Recommended for Development)

To allow the devpod ServiceAccount to create namespaces in the future:

```bash
# Run as cluster-admin
kubectl apply -f devpod-namespace-creator-rbac.yml
kubectl apply -f moltbook-namespace.yml
```

This grants the `devpod:default` ServiceAccount permission to:
- Create, get, list, watch namespaces
- Create/update roles and rolebindings within namespaces
- Manage Traefik middlewares

## Verification

After setup, verify the namespace exists:

```bash
kubectl get namespace moltbook
```

## Troubleshooting

If you see this error from a devpod:
```
Error from server (Forbidden): namespaces is forbidden: User "system:serviceaccount:devpod:default" cannot create resource "namespaces"
```

The RBAC manifest hasn't been applied. Ask a cluster administrator to run Option 2 above.
