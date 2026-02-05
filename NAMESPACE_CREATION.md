# Namespace Creation Instructions

## Problem
The devpod ServiceAccount lacks permissions to create namespaces or apply cluster-level RBAC manifests.

## Solutions

### Option 1: Apply RBAC Manifest (Recommended for GitOps)

Apply the RBAC manifest as cluster-admin to grant the devpod ServiceAccount namespace creation permissions:

```bash
# From a cluster-admin context:
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

After applying, the devpod can create namespaces:
```bash
kubectl create namespace moltbook
```

### Option 2: Manual Namespace Creation

Create the namespace directly as cluster-admin:

```bash
# From a cluster-admin context:
kubectl create namespace moltbook
```

### Option 3: Use ArgoCD (If Available)

If ArgoCD is installed, the Application manifest has `CreateNamespace=true`:

```bash
# From a cluster-admin context:
kubectl apply -f k8s/argocd-application.yml
```

ArgoCD will automatically create the namespace on first sync.

## Current Status

- **RBAC Manifest**: Ready at `k8s/namespace/devpod-namespace-creator-rbac.yml`
- **Namespace**: `moltbook` does not exist yet
- **ArgoCD**: Not installed in the cluster
- **Required Action**: Cluster-admin must apply one of the solutions above

## Tracking

See bead `mo-2adv` for the blocker tracking this issue.
