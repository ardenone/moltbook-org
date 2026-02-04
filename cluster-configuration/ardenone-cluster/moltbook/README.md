# Moltbook Cluster Configuration

This directory contains the complete Kubernetes manifests for deploying Moltbook to the ardenone-cluster.

## 🚨 Deployment Blocker: RBAC Permissions Required

**Current Status**: 🔴 BLOCKED - Awaiting cluster-admin action

The Moltbook deployment requires cluster-admin intervention to grant the devpod ServiceAccount permission to create namespaces. This is a **one-time setup** action.

### Quick Start for Cluster Admins

```bash
# Apply RBAC + Namespace in one command
kubectl apply -f namespace/NAMESPACE_SETUP_REQUEST.yml
```

For detailed instructions, see: [CLUSTER_ADMIN_ACTION_REQUIRED.md](CLUSTER_ADMIN_ACTION_REQUIRED.md)

---

## Directory Structure

```
moltbook/
├── CLUSTER_ADMIN_ACTION_REQUIRED.md    # ⚠️ Cluster admin setup guide
├── namespace/
│   ├── README.md                        # Namespace setup documentation
│   ├── NAMESPACE_SETUP_REQUEST.yml      # Combined RBAC + namespace manifest
│   ├── devpod-namespace-creator-rbac.yml # ClusterRole + ClusterRoleBinding
│   └── moltbook-namespace.yml           # Namespace definition
└── (future) kustomization.yml           # Kustomize build for full deployment
```

---

## Deployment Process

### Step 1: Cluster Admin Action (One-Time)

Apply the RBAC permissions:

```bash
kubectl apply -f namespace/NAMESPACE_SETUP_REQUEST.yml
```

### Step 2: Deploy Moltbook

Once RBAC is in place, deploy from the devpod:

```bash
# Option 1: Using the deployment script (recommended)
/home/coder/Research/moltbook-org/scripts/deploy-moltbook-after-rbac.sh

# Option 2: Manual deployment
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

### Step 3: Verify Deployment

```bash
# Check all resources
kubectl get all -n moltbook

# Check deployments
kubectl get deployments -n moltbook

# Check pods
kubectl get pods -n moltbook

# Check ingress routes
kubectl get ingressroutes -n moltbook
```

---

## What Gets Deployed

When you run `kubectl apply -k`, the following resources are created:

### Database & Cache
- **PostgreSQL**: CloudNativePG cluster (1 primary + replicas)
- **Redis**: Redis cache for session management

### Application
- **moltbook-api**: Python FastAPI backend
- **moltbook-frontend**: React frontend (nginx)

### Configuration
- **SealedSecrets**: Encrypted secrets (GitHub OAuth, database credentials)
- **ConfigMaps**: Application configuration

### Networking
- **Services**: ClusterIP services for API and frontend
- **IngressRoutes**: Traefik routing for external access

---

## Security & RBAC

### Why Cluster Admin Action is Required

The devpod ServiceAccount runs with namespace-scoped permissions. To create namespaces and cluster-scoped RBAC (ClusterRole, ClusterRoleBinding), cluster-admin privileges are required. This is a deliberate Kubernetes security boundary.

### Permissions Granted

The `namespace-creator` ClusterRole grants the devpod ServiceAccount:

- `create`, `get`, `list`, `watch` on `namespaces`
- `get`, `create`, `update`, `patch` on `roles`, `rolebindings`
- `get`, `create`, `update`, `patch`, `delete` on `middlewares` (Traefik)

This follows the principle of least privilege - only the minimum permissions needed for deployment.

---

## Troubleshooting

### RBAC Not Applied

If you get "permissions denied" errors:

```bash
# Check if ClusterRole exists
kubectl get clusterrole namespace-creator

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding devpod-namespace-creator

# Verify devpod SA permissions
kubectl auth can-i create namespaces --as=system:serviceaccount:devpod:default
```

### Namespace Not Found

```bash
# Create namespace manually
kubectl create namespace moltbook
```

### Deployment Fails

Check pod logs:

```bash
# API logs
kubectl logs -n moltbook -l app=moltbook-api --tail=50

# Frontend logs
kubectl logs -n moltbook -l app=moltbook-frontend --tail=50
```

---

## Related Documentation

- **[CLUSTER_ADMIN_ACTION_REQUIRED.md](CLUSTER_ADMIN_ACTION_REQUIRED.md)** - Cluster admin setup guide
- **[namespace/README.md](namespace/README.md)** - Namespace setup documentation
- **[../../RBAC_BLOCKER.md](../../RBAC_BLOCKER.md)** - Detailed RBAC blocker analysis
- **[../../DEPLOYMENT_GUIDE.md](../../DEPLOYMENT_GUIDE.md)** - Complete deployment guide

## Related Beads

- **mo-1te** - Fix Moltbook deployment blocked by missing RBAC permissions (this task)
- **mo-eypj** (P0) - Cluster-admin action: Apply devpod-namespace-creator ClusterRoleBinding
- **mo-3ax** - Investigation and verification of RBAC blocker

---

**Last Updated**: 2026-02-04
**Status**: 🔴 BLOCKED - Awaiting cluster-admin action
**Priority**: P0 (Critical)
