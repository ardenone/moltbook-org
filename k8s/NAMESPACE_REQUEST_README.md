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

### Option 1: Create the Namespace (Recommended - One-Time)

**Cluster Admin Action Required:**

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_REQUEST.yml
```

This creates the `moltbook` namespace with proper labels. After this, devpod can deploy all resources within the namespace.

### Option 2: Grant Namespace Creation Permissions (Alternative - Permanent)

**Cluster Admin Action Required:**

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml
```

This grants the devpod ServiceAccount permission to create namespaces going forward.

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

- **mo-2fr**: This bead (namespace request)
- **mo-saz**: Blocked by namespace creation - deployment of Moltbook platform
