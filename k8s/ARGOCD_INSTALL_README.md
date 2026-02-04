# ArgoCD Installation for ardenone-cluster - Cluster Admin Action Required

## Status: BLOCKED - Requires Cluster Admin

## Summary

ArgoCD is **NOT installed** in ardenone-cluster. The Moltbook platform deployment requires ArgoCD for GitOps operations. This request includes the RBAC permissions needed to install ArgoCD.

## Critical Information

**Current State:**
- ArgoCD namespace: **Does NOT exist**
- Moltbook namespace: **Does NOT exist**
- Devpod RBAC: **Insufficient for ArgoCD installation**

**Required for ArgoCD Installation:**
- CustomResourceDefinitions (cluster-scoped)
- ClusterRoles and ClusterRoleBindings (cluster-scoped)
- Namespace creation (cluster-scoped)

## Quick Fix (For Cluster Admins)

### Step 1: Grant ArgoCD Installation Permissions

```bash
# From the moltbook-org directory
kubectl apply -f k8s/ARGOCD_INSTALL_REQUEST.yml
```

This manifest:
1. Creates a ClusterRole with ArgoCD installation permissions
2. Binds the ClusterRole to the devpod ServiceAccount
3. Creates the `argocd` namespace
4. Creates the `moltbook` namespace

### Step 2: Verify RBAC Applied

```bash
# Verify the ClusterRole was created
kubectl get clusterrole argocd-installer

# Verify the ClusterRoleBinding was created
kubectl get clusterrolebinding devpod-argocd-installer

# Verify namespaces exist
kubectl get namespace argocd
kubectl get namespace moltbook
```

## After Cluster Admin Action

Once the RBAC is granted, the devpod can automatically install ArgoCD:

```bash
# Install ArgoCD (from devpod)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply the Moltbook ArgoCD Application manifest
kubectl apply -f k8s/argocd-application.yml
```

## Verification

### Verify ArgoCD Installation

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0                    1/1     Running   0          2m
# argocd-applicationset-controller-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
# argocd-dex-server-xxxxxxxxxx-xxxxx                 1/1     Running   0          2m
# argocd-notifications-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# argocd-redis-xxxxxxxxxx-xxxxx                      1/1     Running   0          2m
# argocd-repo-server-xxxxxxxxxx-xxxxx                1/1     Running   0          2m
# argocd-server-xxxxxxxxxx-xxxxx                     1/1     Running   0          2m

# Check ArgoCD Application
kubectl get application -n argocd

# Expected output:
# NAME       SYNC STATUS   HEALTH STATUS
# moltbook   Synced        Healthy
```

### Verify Moltbook Deployment

```bash
# Check Moltbook pods
kubectl get pods -n moltbook

# Expected output (after sync completes):
# NAME                                    READY   STATUS    RESTARTS   AGE
# moltbook-api-xxxxxxxxxx-xxxxx           1/1     Running   0          1m
# moltbook-frontend-xxxxxxxxxx-xxxxx      1/1     Running   0          1m
# moltbook-postgresql-0                   1/1     Running   0          2m
# moltbook-redis-xxxxxxxxxx-xxxxx         1/1     Running   0          2m
```

## Architecture

```
ardenone-cluster
├── argocd namespace (ArgoCD installation)
│   ├── argocd-server (UI & API)
│   ├── argocd-application-controller (sync engine)
│   ├── argocd-repo-server (Git repo access)
│   └── (other ArgoCD components)
│
└── moltbook namespace (Moltbook platform)
    ├── moltbook-api (backend service)
    ├── moltbook-frontend (Next.js frontend)
    ├── moltbook-postgresql (CloudNativePG)
    ├── moltbook-redis (cache)
    └── (Traefik IngressRoutes)
```

## Files Reference

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC + namespaces for ArgoCD installation
- `k8s/argocd-application.yml` - ArgoCD Application manifest for Moltbook
- `k8s/CLUSTER_ADMIN_README.md` - Previous namespace setup request (superseded)

## Blocking

This is blocking:
- **mo-saz**: Moltbook platform deployment
- **mo-23p**: Moltbook deployment verification
- **mo-3tx**: This bead (ArgoCD installation)
- All other Moltbook-related beads

## Security Considerations

The `argocd-installer` ClusterRole grants the devpod ServiceAccount:

1. **Cluster-scoped permissions:**
   - Create/modify/delete CRDs (required for ArgoCD)
   - Create/modify/delete ClusterRoles/ClusterRoleBindings (required for ArgoCD)
   - Create/modify/delete namespaces (required for initial setup)

2. **Why this is safe:**
   - These permissions are required for ArgoCD installation
   - The devpod is a trusted environment within the cluster
   - The permissions are scoped to installation, not arbitrary cluster administration

3. **Recommendation:**
   - After ArgoCD is installed, consider removing the installer permissions
   - ArgoCD will manage deployments via its own service account
   - The devpod can manage applications via ArgoCD API

## Alternative Approaches

### Alternative 1: Cluster Admin Installs ArgoCD Directly

If the cluster admin prefers to install ArgoCD directly:

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace moltbook

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply the Moltbook Application
kubectl apply -f k8s/argocd-application.yml
```

### Alternative 2: Direct kubectl apply (No ArgoCD)

If ArgoCD is not required, deploy directly:

```bash
# Create namespace
kubectl create namespace moltbook

# Deploy manifests directly
kubectl apply -k k8s/
```

**Note:** This violates GitOps principles and is not recommended for production.
