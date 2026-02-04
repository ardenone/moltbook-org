# Namespace Request: Moltbook Platform

## Current Status

The `moltbook` namespace does NOT exist in the cluster.

```
$ kubectl get namespace moltbook
Error: Namespace "moltbook" not found
```

## Problem

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks permission to create namespaces at cluster scope. This is blocking deployment of the Moltbook platform.

## Solution Options

### Option 1: Grant RBAC + Create Namespace (Recommended for Development)

**Cluster Admin Action Required:**

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
- `ClusterRole`: namespace-creator (grants namespace creation to devpod)
- `ClusterRoleBinding`: devpod-namespace-creator
- The `moltbook` namespace

After this, devpod can both create namespaces AND deploy all resources.

### Option 2: Create the Namespace Only (Quickest - for manual deployment)

**Cluster Admin Action Required:**

```bash
kubectl create namespace moltbook
```

After this, devpod can deploy all resources within the namespace using `kubectl apply -k k8s/`.

### Option 3: ArgoCD GitOps Deployment (Alternative - requires ArgoCD installation)

**Note:** ArgoCD is NOT installed in ardenone-cluster. This option requires ArgoCD to be installed first.

If ArgoCD is available, a cluster admin can run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
```

ArgoCD will automatically:
- Create the `moltbook` namespace (`CreateNamespace=true`)
- Deploy all resources from the k8s/ directory
- Keep everything in sync with Git

## After Namespace is Created

Once the namespace exists, deployment proceeds automatically:

```bash
kubectl apply -k k8s/
```

This will deploy:
1. SealedSecrets (auto-decrypted by sealed-secrets controller)
2. PostgreSQL cluster (CNPG)
3. Redis deployment
4. API backend deployment
5. Frontend deployment
6. Ingress routes (Traefik)
7. RBAC for devpod management

## Verification

After namespace creation, verify:

```bash
kubectl get namespace moltbook
kubectl get all -n moltbook
```

## Related Beads

- **mo-3rs**: This bead (Fix: Grant devpod namespace creation permissions or create moltbook namespace)
- **mo-saz**: Blocked by namespace creation - deployment of Moltbook platform

## Documentation

- `k8s/CLUSTER_ADMIN_README.md` - Quick reference for cluster admins
- `k8s/DEPLOYMENT_BLOCKER.md` - Full blocker analysis
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest
