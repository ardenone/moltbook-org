# ArgoCD Installation Blocker Resolution Guide - ardenone-cluster

**Task**: mo-1eat - DOCS: Document ArgoCD installation blocker resolution steps
**Date**: 2026-02-05
**Status**: BLOCKED - Requires cluster-admin privileges
**Action Bead**: mo-21sg (Priority 0 - Critical) - CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation

## Summary

ArgoCD is NOT installed in ardenone-cluster. The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks the necessary cluster-admin permissions to install ArgoCD, which requires:

1. CustomResourceDefinition creation (cluster-scoped)
2. ClusterRole/ClusterRoleBinding creation (cluster-scoped)
3. Namespace creation (cluster-scoped)

## Current Blocker Status (mo-21sg)

| Check | Result | Details |
|-------|--------|---------|
| argocd namespace | NotFound | `kubectl get namespace argocd` returns NotFound |
| ArgoCD CRDs | Not installed | Only Argo Rollouts CRDs exist |
| devpod permissions | Insufficient | Cannot create CRDs or cluster-scoped resources |
| RBAC application attempt | Failed | Error: User "system:serviceaccount:devpod:default" cannot create clusterroles/clusterrolebindings/namespaces |

### Confirmed Permission Gaps

| Permission | Status | Command Result |
|------------|--------|----------------|
| Create CustomResourceDefinitions | DENIED | `no` (cluster-scoped) |
| Create Namespaces | DENIED | `no` (cluster-scoped) |
| Create ClusterRole | DENIED | `no` (cluster-scoped) |
| Create ClusterRoleBinding | DENIED | `no` (cluster-scoped) |
| List services across namespaces | DENIED | `Forbidden` |

## Prerequisites for Installation

Before installing ArgoCD, ensure:

1. **Cluster-admin access** to ardenone-cluster
2. **kubectl configured** with cluster-admin context
3. **Network connectivity** to github.com (for ArgoCD manifest)
4. **Sufficient resources** in the cluster (ArgoCD requires ~2GB RAM, 2 CPU cores minimum)

## Step-by-Step Installation Commands

### Option 1: Grant Cluster-Admin + Install (Recommended for Development)

**Step 1: Cluster Admin - Grant cluster-admin to devpod ServiceAccount**

```bash
# Execute this command from a machine with cluster-admin access
kubectl create clusterrolebinding devpod-cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=devpod:default
```

**Step 2: From devpod - Verify permissions**

```bash
# Run the readiness verification script
./k8s/verify-argocd-ready.sh
```

Expected output:
```
========================================================================
ArgoCD Installation Readiness Verification
========================================================================

Checking namespace creation permission... PASS: Can create namespaces
Checking CRD creation permission... PASS: Can create CRDs
Checking ClusterRole creation permission... PASS: Can create ClusterRoles
Checking ClusterRoleBinding creation permission... PASS: Can create ClusterRoleBindings
Checking argocd namespace... PASS: argocd namespace can be created
Checking moltbook namespace... PASS: moltbook namespace can be created

========================================================================
Summary
========================================================================
Passed: 6
Failed: 0

READY: All prerequisites met. You can now install ArgoCD
```

**Step 3: From devpod - Install ArgoCD**

```bash
# Option A: Use the installation script (recommended)
./k8s/install-argocd.sh

# Option B: Manual installation
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Step 4: From devpod - Wait for ArgoCD to be ready**

```bash
# Wait for ArgoCD pods to be ready (timeout 5 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

**Step 5: From devpod - Apply Moltbook ArgoCD Application**

```bash
kubectl apply -f k8s/argocd-application.yml
```

---

### Option 2: Direct Cluster Admin Installation (Quickest)

If the cluster admin prefers to install ArgoCD directly:

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace moltbook

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Moltbook Application
kubectl apply -f k8s/argocd-application.yml
```

---

### Option 3: Apply RBAC Manifest First (Alternative)

Use the prepared RBAC manifest that grants ArgoCD installation permissions:

```bash
# Step 1: Cluster Admin - Apply the RBAC manifest
kubectl apply -f k8s/ARGOCD_INSTALL_REQUEST.yml

# Step 2: From devpod - Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 3: From devpod - Apply Moltbook Application
kubectl apply -f k8s/argocd-application.yml
```

This manifest will:
1. Create `argocd-installer` ClusterRole with necessary permissions
2. Bind it to `devpod:default` ServiceAccount via `devpod-argocd-installer` ClusterRoleBinding
3. Create `argocd` namespace
4. Create `moltbook` namespace

## Post-Installation Verification Steps

After installation, verify ArgoCD is running correctly:

```bash
# 1. Verify ArgoCD pods are running
kubectl get pods -n argocd

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0           1/1     Running   0          1m
# argocd-application-set-controller-...     1/1     Running   0          1m
# argocd-notifications-controller-...       1/1     Running   0          1m
# argocd-redis-...                          1/1     Running   0          1m
# argocd-repo-server-...                    1/1     Running   0          1m
# argocd-server-...                         1/1     Running   0          1m

# 2. Verify ArgoCD CRDs are installed
kubectl get crds | grep argoproj.io

# Expected output includes:
# applications.argoproj.io
# appprojects.argoproj.io
# applicationsets.argoproj.io
# argocdextensions.argoproj.io

# 3. Verify Moltbook Application
kubectl get application moltbook -n argocd

# 4. Verify Moltbook resources
kubectl get all -n moltbook
kubectl get ingressroutes -n moltbook
kubectl get clusters.cnpg.io -n moltbook
```

### Quick Verification Script

```bash
# Run the verification script
./k8s/install-argocd.sh --verify
```

## How to Access ArgoCD UI

### Method 1: Port-Forwarding (Recommended for Local Access)

```bash
# Forward ArgoCD server port to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# In another terminal, get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI at:
# https://localhost:8080
# Username: admin
# Password: <output from command above>
```

### Method 2: IngressRoute (Recommended for Production Access)

To expose ArgoCD via Traefik IngressRoute:

```yaml
# k8s/argocd/ingressroute.yml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argocd.ardenone.com`)
      kind: Rule
      services:
        - name: argocd-server
          port: 443
  tls:
    certResolver: letsencrypt
```

Apply with:
```bash
kubectl apply -f k8s/argocd/ingressroute.yml
```

Then access at: `https://argocd.ardenone.com`

## Expected Resources After ArgoCD Sync

The Moltbook ArgoCD Application at `k8s/argocd-application.yml` will deploy:

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

## Related Documentation

- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for cluster-admin
- `k8s/install-argocd.sh` - Installation script with verification
- `k8s/verify-argocd-ready.sh` - Prerequisites verification script
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application
- `k8s/ARGOCD_INSTALLATION_GUIDE.md` - Detailed installation guide
- `k8s/CLUSTER_ADMIN_README.md` - Quick start for cluster admins

## Next Steps

1. **Cluster Admin**: Execute action bead **mo-21sg** to grant cluster-admin:
   ```bash
   kubectl create clusterrolebinding devpod-cluster-admin --clusterrole=cluster-admin --serviceaccount=devpod:default
   ```
2. **Run Verification**: `./k8s/verify-argocd-ready.sh`
3. **Run Installation Script**: `./k8s/install-argocd.sh`
4. **Verify**: `kubectl get pods -n argocd` shows ArgoCD running
5. **Deploy Moltbook**: `kubectl apply -f k8s/argocd-application.yml`
6. **Close beads**: mo-y5o and mo-1eat can be closed after successful installation

---

**Last Updated**: 2026-02-05
**Task**: mo-1eat (claude-glm-bravo worker)
**Status**: BLOCKED - Awaiting cluster-admin action
**Blocker Bead**: mo-21sg - CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation

## Additional Findings (2026-02-04)

### Existing Infrastructure Discovered

1. **argocd-manager ClusterRole exists**: A powerful ClusterRole `argocd-manager-role` exists with `*` permissions on all resources
2. **External ArgoCD**: There's an external ArgoCD instance at `argocd-manager.ardenone.com` that the devpod proxies to
3. **Proxy Service**: An `argocd-proxy` deployment exists in the `devpod` namespace

### Why This Doesn't Solve the Problem

The external ArgoCD at `argocd-manager.ardenone.com` cannot manage Applications within ardenone-cluster because:
- ArgoCD Applications are cluster-scoped resources that must be managed by an in-cluster ArgoCD instance
- The Moltbook Application at `k8s/argocd-application.yml` references an in-cluster ArgoCD server: `https://kubernetes.default.svc`
- GitOps requires the ArgoCD controller to be running inside the cluster to monitor and reconcile resources
