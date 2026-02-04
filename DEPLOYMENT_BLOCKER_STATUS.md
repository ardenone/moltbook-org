# Moltbook Deployment Blocker Status

**Last Updated**: 2026-02-04 19:35 UTC
**Bead**: mo-32c (namespace creation task)
**Blocker Bead**: mo-2bxj (P0 - Critical) - Cluster admin action required

---

## Status: BLOCKED - Requires Cluster Admin Action

### Summary

The Moltbook platform deployment is **blocked** because:
1. The `moltbook` namespace does not exist
2. The devpod ServiceAccount (`system:serviceaccount:devpod:default`) lacks cluster-admin privileges to create namespaces
3. No `namespace-creator` ClusterRole/ClusterRoleBinding exists

---

## Verification

```bash
$ kubectl auth can-i create namespace
no

$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found

$ kubectl get clusterrole namespace-creator
Error from server (NotFound): clusterroles.rbac.authorization.k8s.io "namespace-creator" not found
```

---

## Resolution: Cluster Admin Action Required

### Single Command Setup

A cluster administrator must run:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

### What This Creates

| Resource | Purpose |
|----------|---------|
| `ClusterRole: namespace-creator` | Grants namespace creation + RBAC management permissions |
| `ClusterRoleBinding: devpod-namespace-creator` | Binds ClusterRole to devpod:default ServiceAccount |
| `Namespace: moltbook` | The target namespace for all Moltbook resources |

---

## After Cluster Admin Action

Once the namespace exists, deploy from devpod:

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

---

## What Gets Deployed

| Component | Resources | Image |
|-----------|-----------|-------|
| **Database** | CloudNativePG cluster (1 instance, 10Gi), Services, Init | `ghcr.io/cloudnative-pg/postgresql:16.3` |
| **Cache** | Redis Deployment (1 replica), Service, ConfigMap | `redis:7-alpine` |
| **API** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-api:latest` |
| **Frontend** | Deployment (2 replicas), Service, IngressRoute | `ghcr.io/ardenone/moltbook-frontend:latest` |
| **Secrets** | 3 SealedSecrets (API, DB, Postgres) | Pre-encrypted |

---

## Access Points (Post-Deployment)

- **Frontend**: https://moltbook.ardenone.com
- **API**: https://api-moltbook.ardenone.com
- **API Health**: https://api-moltbook.ardenone.com/health

---

## Verification Checklist (Post-Deployment)

```bash
# Verify RBAC applied
kubectl get clusterrole namespace-creator
kubectl get clusterrolebinding devpod-namespace-creator
kubectl get namespace moltbook

# Verify deployment
kubectl get pods -n moltbook
kubectl get svc -n moltbook
kubectl get ingressroutes -n moltbook

# Test endpoints
curl https://api-moltbook.ardenone.com/health
curl https://moltbook.ardenone.com
```

---

## Related Files

| File | Purpose |
|------|---------|
| `k8s/NAMESPACE_SETUP_REQUEST.yml` | Cluster-admin setup manifest (RBAC + namespace) |
| `k8s/setup-namespace.sh` | Automated setup script |
| `k8s/kustomization.yml` | Full deployment (includes namespace) |
| `k8s/kustomization-no-namespace.yml` | Deployment without namespace (alternative) |
| `k8s/argocd-application.yml` | ArgoCD Application manifest (GitOps) |

---

## Bead Tracking

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-32c | Create moltbook namespace in ardenone-cluster | 1 | BLOCKED |
| mo-cx8 | Deploy: Apply Moltbook manifests to ardenone-cluster | 1 | BLOCKED |
| mo-2bxj | BLOCKER: Cluster Admin - Apply RBAC for Moltbook namespace creation | 0 | OPEN |

---

## Architecture (Post-Deployment)

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance, 10Gi)
  │   ├─ moltbook-postgres-rw Service (ReadWrite)
  │   └─ moltbook-postgres-ro Service (ReadOnly)
  │
  ├─ moltbook-redis (Deployment, 1 replica)
  │   └─ moltbook-redis Service (6379)
  │
  ├─ moltbook-db-init (Deployment, 1 replica)
  │   └─ Runs schema initialization (idempotent)
  │
  ├─ moltbook-api (Deployment, 2 replicas)
  │   └─ moltbook-api Service (port 80)
  │       └─ IngressRoute: api-moltbook.ardenone.com
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service (port 80)
          └─ IngressRoute: moltbook.ardenone.com
```

---

## Security & GitOps Compliance

- All secrets encrypted with SealedSecrets
- No plaintext secrets in Git
- No Job/CronJob manifests (ArgoCD compatible)
- All resources use idempotent Deployments
- Traefik IngressRoute (not standard Ingress)
- Single-level subdomains (Cloudflare compatible)
- Health checks on all deployments
- Resource limits defined
- RBAC scoped to namespace
