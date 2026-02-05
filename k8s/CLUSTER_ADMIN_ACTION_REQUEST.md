# CLUSTER ADMIN ACTION REQUEST: Moltbook Namespace Setup

**Bead:** mo-1ywd
**Date:** 2026-02-05 16:17 UTC
**Status:** AWAITING CLUSTER ADMIN ACTION
**Location:** ardenone-cluster

---

## Summary

The Moltbook platform deployment is **blocked** because the `moltbook` namespace does not exist and cannot be created from the devpod ServiceAccount. This requires **cluster-admin privileges**.

---

## Verification Results (2026-02-05 11:50 UTC)

```
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found

$ kubectl get clusterrolebinding devpod-namespace-creator
Error from server (NotFound): clusterrolebindings.rbac.authorization.k8s.io "devpod-namespace-creator" not found

$ kubectl auth can-i create clusterrole
no (devpod SA lacks cluster-admin)
```

---

## Required Action (Cluster Admin Only)

### Option 1: Automated Script (Recommended)

```bash
# From any host with cluster-admin access to ardenone-cluster
/home/coder/Research/moltbook-org/k8s/setup-namespace.sh
```

### Option 2: Manual kubectl Apply

```bash
# From any host with cluster-admin access to ardenone-cluster
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

---

## What These Commands Create

1. **ClusterRole: `namespace-creator`**
   - Grants namespace creation permissions

2. **ClusterRoleBinding: `devpod-namespace-creator`**
   - Binds ClusterRole to devpod ServiceAccount

3. **Namespace: `moltbook`**
   - Target namespace for Moltbook deployment

---

## After Cluster Admin Action

Once the namespace exists, the devpod ServiceAccount can deploy all Moltbook resources:

```bash
# From within the devpod
kubectl apply -k /home/coder/Research/moltbook-org/k8s/
```

---

## Deployment Architecture

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance, 10Gi)
  ├─ moltbook-redis (Deployment, 1 replica)
  ├─ moltbook-db-init (Deployment, 1 replica)
  ├─ moltbook-api (Deployment, 2 replicas)
  └─ moltbook-frontend (Deployment, 2 replicas)
```

---

## Access Points

- **Frontend:** https://moltbook.ardenone.com
- **API:** https://api-moltbook.ardenone.com
- **API Health:** https://api-moltbook.ardenone.com/health

---

## Files Reference

- `/home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml` - Consolidated setup manifest
- `/home/coder/Research/moltbook-org/k8s/setup-namespace.sh` - Automated setup script
- `/home/coder/Research/moltbook-org/k8s/kustomization.yml` - Full deployment manifests

---

## Related Beads

- **mo-1ywd** (ACTIVE): BLOCKER: Cluster Admin - Apply Moltbook namespace setup manifest
- **mo-saz** (BLOCKED): Moltbook platform deployment (waiting for namespace)

---

**Next Step:** Cluster administrator runs the setup script or applies the manifest.
