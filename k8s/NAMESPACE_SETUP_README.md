# Moltbook Namespace Setup - Cluster Admin Action Required

## Status: BLOCKED - Requires Cluster Admin

## Summary

The `moltbook` namespace cannot be created by the devpod ServiceAccount (`system:serviceaccount:devpod:default`) because creating namespaces is a cluster-scoped operation that requires elevated permissions.

## Quick Fix (For Cluster Admins)

### Option 1: Automated Setup (Recommended)

Run the provided setup script:

```bash
./k8s/setup-namespace.sh
```

This script will:
1. Grant namespace creation permissions to the devpod ServiceAccount
2. Create the `moltbook` namespace
3. Verify everything is set up correctly

### Option 2: Manual Setup

Apply the consolidated manifest:

```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

### Option 3: Direct Namespace Creation (Minimal)

If you don't want to grant additional permissions to devpod, simply create the namespace:

```bash
kubectl create namespace moltbook
```

> **Note:** Option 3 only creates the namespace. The devpod ServiceAccount can still deploy resources into an existing namespace. However, Option 1 or 2 is recommended for future namespace management needs.
>
> **Important:** ArgoCD is NOT installed in ardenone-cluster. The ArgoCD application manifest (`k8s/argocd-application.yml`) is for a different cluster or requires ArgoCD installation first.

## After Setup

Once the namespace exists, the deployment can proceed from the devpod:

```bash
# From within the devpod
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

## Verification

Verify the namespace was created:

```bash
kubectl get namespace moltbook
```

Expected output:
```
NAME       STATUS   AGE
moltbook   Active   <age>
```

## What Gets Deployed

After namespace creation, the following resources will be deployed:

1. **SealedSecrets** - Encrypted secrets (auto-decrypted by sealed-secrets controller)
2. **PostgreSQL** - CloudNativePG database cluster
3. **Redis** - Caching layer
4. **API Backend** - moltbook-api deployment
5. **Frontend** - moltbook-frontend deployment (Next.js)
6. **Ingress Routes** - Traefik routes for external access

## Files Reference

- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated setup manifest (RBAC + namespace)
- `k8s/setup-namespace.sh` - Automated setup script
- `k8s/namespace/devpod-namespace-creator-rbac.yml` - RBAC only
- `k8s/namespace/moltbook-namespace.yml` - Namespace only
- `k8s/kustomization-no-namespace.yml` - Deployment without namespace resource
