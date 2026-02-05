# Namespace Blocker Verification - mo-2mws

**Date:** 2026-02-05 13:20 UTC
**Bead:** mo-2mws - BLOCKER: Grant namespace creation permissions for Moltbook deployment
**Status:** BLOCKED - Requires cluster admin action

## Summary

The Moltbook deployment is blocked because the `moltbook` namespace does not exist and the devpod ServiceAccount lacks the permissions to create it.

## Verification Results

### ardenone-cluster (local, in-cluster access)

```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found
```

```bash
$ kubectl auth can-i create namespaces
no
```

**Result:** Namespace does not exist, ServiceAccount cannot create it.

### apexalgo-iad (remote, via kubectl-proxy)

```bash
$ KUBECONFIG=/home/coder/.kube/apexalgo-iad.kubeconfig kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found
```

```bash
$ KUBECONFIG=/home/coder/.kube/apexalgo-iad.kubeconfig kubectl auth can-i create namespaces
no
```

**Result:** Namespace does not exist, ServiceAccount cannot create it.

## Cluster Admin Action Required

Run this single command from the moltbook-org directory:

```bash
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

This will:
1. Create ClusterRole `namespace-creator` with namespace creation permissions
2. Create ClusterRoleBinding `devpod-namespace-creator` to grant permissions to devpod ServiceAccount
3. Create the `moltbook` namespace

## Related Beads

- **mo-2rtw** - CLUSTER-ADMIN: Apply NAMESPACE_SETUP_REQUEST.yml for Moltbook deployment (NEW - P0)
- **mo-3uep** - Fix: Cluster-admin action - Create moltbook namespace for Moltbook deployment
- **mo-dsvl** - BLOCKER: Cluster-admin required - Apply NAMESPACE_SETUP_REQUEST.yml
- **mo-14bm** - BLOCKER: Cluster-admin required - Create moltbook namespace and RBAC

## After Cluster Admin Action

Once the namespace exists, deployment is automatic:

```bash
kubectl apply -k k8s/
```

This will deploy:
1. SealedSecrets (encrypted secrets)
2. PostgreSQL cluster (CloudNativePG)
3. Redis cache
4. moltbook-api deployment
5. moltbook-frontend deployment
6. Traefik IngressRoutes

## Documentation

- `k8s/CLUSTER_ADMIN_README.md` - Detailed cluster admin instructions
- `k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated RBAC + namespace manifest
