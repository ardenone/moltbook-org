# Moltbook Namespace Setup

This directory contains manifests for setting up the Moltbook namespace in the ardenone-cluster.

## Current Status (2026-02-04)

**BLOCKED - Awaiting Cluster Admin Action**

- Namespace `moltbook`: **Does NOT exist**
- RBAC `devpod-namespace-creator`: **NOT applied**
- Blocker bead: **mo-3c3c** (Fix: Create moltbook namespace in ardenone-cluster)
- Helper script: `../scripts/setup-namespace.sh` (run from k8s directory)

## Prerequisites

This setup requires **cluster-admin** privileges to create namespaces and apply RBAC.

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
