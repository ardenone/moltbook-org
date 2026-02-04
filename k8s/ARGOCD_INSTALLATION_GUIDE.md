# ArgoCD Installation Guide for ardenone-cluster

**Bead**: mo-3tx - Task: Install ArgoCD in ardenone-cluster for Moltbook deployment
**Date**: 2026-02-04
**Status**: BLOCKER - Requires cluster-admin privileges

## Summary

ArgoCD is NOT installed in ardenone-cluster. This guide provides step-by-step instructions for a cluster administrator to install ArgoCD and configure it for Moltbook deployment.

## Current State

- **ArgoCD Namespace**: Does NOT exist
- **ArgoCD CRDs**: NOT installed (only Argo Rollouts CRDs exist)
- **ArgoCD Components**: NOT deployed
- **devpod SA Permissions**: Cannot create cluster-scoped resources (namespaces, CRDs)

## Prerequisites

- Kubernetes cluster-admin access to ardenone-cluster
- kubectl configured with cluster-admin context

## Installation Steps

### Step 1: Create the argocd Namespace

```bash
kubectl create namespace argocd
```

### Step 2: Install ArgoCD

Download and apply the official ArgoCD manifests:

```bash
# Option A: Install from official manifest (stable release)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Option B: Install from local file (already downloaded to /tmp/argocd-install.yaml)
kubectl apply -n argocd -f /tmp/argocd-install.yaml

# Option C: Using kustomize (for custom configuration)
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/cluster-install?ref=stable
```

### Step 3: Verify Installation

```bash
# Check ArgoCD pods are running
kubectl get pods -n argocd

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0           1/1     Running   0          1m
# argocd-application-set-controller-...     1/1     Running   0          1m
# argocd-notifications-controller-...       1/1     Running   0          1m
# argocd-redis-...                          1/1     Running   0          1m
# argocd-repo-server-...                    1/1     Running   0          1m
# argocd-server-...                         1/1     Running   0          1m

# Check ArgoCD CRDs are installed
kubectl get crds | grep argoproj.io

# Expected output includes:
# applications.argoproj.io
# appprojects.argoproj.io
# argocdextensions.argoproj.io
# etc.
```

### Step 4: Access ArgoCD UI (Optional)

```bash
# Expose ArgoCD server via LoadBalancer or IngressRoute
# For now, use port-forwarding for local access:
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login at: https://localhost:8080
# Username: admin
# Password: <output from above command>
```

### Step 5: Apply Moltbook ArgoCD Application

```bash
# From the moltbook-org repository root:
kubectl apply -f k8s/argocd-application.yml
```

### Step 6: Verify Moltbook Deployment

```bash
# Check Application sync status
kubectl get application moltbook -n argocd

# Check deployed resources
kubectl get all -n moltbook
kubectl get ingressroutes -n moltbook
kubectl get clusters.cnpg.io -n moltbook

# Monitor sync progress
kubectl get application moltbook -n argocd -w
```

## ArgoCD Application Configuration

The Moltbook ArgoCD Application is pre-configured at `k8s/argocd-application.yml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/moltbook-org.git
    targetRevision: main
    path: k8s
    kustomize:
      images:
        - ghcr.io/ardenone/moltbook-api:latest
        - ghcr.io/ardenone/moltbook-frontend:latest
  destination:
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true  # Auto-create namespace on first sync
```

## Expected Resources After Sync

### Database Layer
- PostgreSQL (CNPG): `moltbook-db` cluster with 1 replica
- Schema Init Deployment

### Cache Layer
- Redis Deployment and Service

### API Backend
- Deployment (2 replicas)
- Service
- IngressRoute (`api-moltbook.ardenone.com`)

### Frontend
- Deployment (2 replicas)
- Service
- IngressRoute (`moltbook.ardenone.com`)

### Secrets
- SealedSecrets for API credentials
- SealedSecrets for PostgreSQL credentials

## Alternative: Direct kubectl Deployment

If ArgoCD installation is not feasible, Moltbook can be deployed directly:

```bash
# Requires cluster-admin for namespace creation
kubectl create namespace moltbook

# Apply RBAC for devpod SA
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml

# Deploy all resources
kubectl apply -k k8s/
```

**Note**: This approach violates GitOps principles and requires manual updates for future changes.

## Troubleshooting

### ArgoCD pods not starting
```bash
kubectl logs -n argocd deployment/argocd-server
kubectl describe pod -n argocd <pod-name>
```

### Application sync failing
```bash
# Check application status
kubectl get application moltbook -n argocd -o yaml

# Check sync status
kubectl get application moltbook -n argocd -o jsonpath='{.status.sync.status}'

# Check operation status
kubectl get application moltbook -n argocd -o jsonpath='{.status.operationState}'
```

### Namespace not created automatically
- Verify `CreateNamespace=true` is set in syncOptions
- Check ArgoCD controller has sufficient RBAC permissions
- Manually create namespace: `kubectl create namespace moltbook`

## Verification Log (mo-3tx - 2026-02-04 21:51 UTC)

| Check | Result | Command |
|-------|--------|---------|
| argocd namespace exists | NotFound | `kubectl get namespace argocd` |
| ArgoCD CRDs installed | No (only Argo Rollouts) | `kubectl get crds \| grep argoproj.io` |
| argocd-installer ClusterRole exists | NotFound | `kubectl get clusterrole argocd-installer` |
| devpod-argocd-installer ClusterRoleBinding exists | NotFound | `kubectl get clusterrolebinding devpod-argocd-installer` |
| Current identity | `system:serviceaccount:devpod:default` | `kubectl auth whoami` |

**Conclusion from mo-3tx**: ArgoCD is NOT installed in ardenone-cluster. RBAC has NOT been applied. This task CANNOT be completed autonomously - requires cluster administrator action.

## Related Beads

- **mo-3viq** (P0) - Fix: Apply argocd-installer RBAC and install ArgoCD in ardenone-cluster [CLUSTER-ADMIN ACTION - CREATED BY mo-3tx]
- **mo-3tx** (P0) - CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment [THIS BEAD - DOCUMENTATION COMPLETE]
- **mo-saz** (P0) - Moltbook platform deployment to ardenone-cluster
- **mo-32d** (P0) - Fix: Apply devpod-namespace-creator ClusterRoleBinding for Moltbook
- **mo-3aw** (P0) - Fix: Create moltbook namespace in ardenone-cluster

## Cluster Admin Action Required

To proceed with ArgoCD installation, a cluster administrator must:

```bash
# Step 1: Apply RBAC and create namespaces
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml

# Step 2: Install ArgoCD (from devpod, after RBAC is applied)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 3: Apply Moltbook ArgoCD Application
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# Step 4: Verify installation
kubectl get pods -n argocd
kubectl get application moltbook -n argocd
kubectl get all -n moltbook
```

## Next Steps

1. Cluster-admin executes action bead **mo-3viq** with commands above
2. After ArgoCD is installed, bead mo-saz can proceed with deployment
3. Bead mo-3tx is complete (documentation prepared, blocker identified, action bead created)
