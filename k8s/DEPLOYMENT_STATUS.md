# Moltbook Deployment Status - ardenone-cluster

**Last Updated**: 2026-02-04 19:22 UTC
**Bead**: mo-cx8
**Task**: Deploy: Apply Moltbook manifests to ardenone-cluster
**Status**: 🟡 BLOCKED - Awaiting Cluster Admin Action

---

## Summary

All Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster are **complete and validated**. The deployment is blocked because the `devpod` ServiceAccount lacks permission to create namespaces at the cluster level.

| Component | Status | Notes |
|-----------|--------|-------|
| API Backend | ✅ Ready | Container image available in GHCR |
| Frontend | ✅ Ready | Container image available in GHCR |
| Database (PostgreSQL) | ✅ Ready | CloudNativePG manifests ready |
| Redis | ✅ Ready | Deployment manifests ready |
| Kubernetes Manifests | ✅ Validated | Kustomization builds successfully |
| SealedSecrets | ✅ Ready | 3 encrypted secrets (API, DB, Postgres) |
| RBAC | ❌ Blocked | Namespace creation requires cluster-admin |

---

## Resolution: Single Command for Cluster Admin

A cluster administrator must run this single command:

```bash
kubectl apply -f /home/coder/Research/moltbook-org/k8s/NAMESPACE_SETUP_REQUEST.yml
```

**This creates:**
1. `ClusterRole: namespace-creator` - Grants namespace creation + RBAC management
2. `ClusterRoleBinding: devpod-namespace-creator` - Binds to devpod:default ServiceAccount
3. `Namespace: moltbook` - The target namespace for deployment

---

## After RBAC is Applied

### Option A: Kubectl Apply (Immediate)
```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

### Option B: ArgoCD GitOps (Continuous Sync)
```bash
kubectl apply -f k8s/argocd-application.yml
```

---

## Container Images

| Component | Image Reference | Status |
|-----------|-----------------|--------|
| API Backend | `ghcr.io/ardenone/moltbook-api:latest` | ✅ Available |
| Frontend | `ghcr.io/ardenone/moltbook-frontend:latest` | ✅ Available |

---

## Post-Deployment Architecture

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

## Access Points (Post-Deployment)

- **Frontend:** https://moltbook.ardenone.com
- **API:** https://api-moltbook.ardenone.com
- **API Health:** https://api-moltbook.ardenone.com/health

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

| Purpose | File Path |
|---------|-----------|
| RBAC + Namespace (requires admin) | `k8s/NAMESPACE_SETUP_REQUEST.yml` |
| RBAC only | `k8s/namespace/devpod-namespace-creator-rbac.yml` |
| Main kustomization | `k8s/kustomization.yml` |
| No-namespace variant | `k8s/kustomization-no-namespace.yml` |
| ArgoCD Application | `k8s/argocd-application.yml` |
| Setup script | `k8s/setup-namespace.sh` |
| Detailed blocker info | `k8s/DEPLOYMENT_BLOCKER.md` |

---

## Blocker Bead

- **mo-1e6t** [P0]: Blocker: Apply namespace-creator ClusterRole for Moltbook deployment

---

## Security & GitOps Compliance

- ✅ All secrets encrypted with SealedSecrets
- ✅ No plaintext secrets in Git
- ✅ No Job/CronJob manifests (ArgoCD compatible)
- ✅ All resources use idempotent Deployments
- ✅ Traefik IngressRoute (not standard Ingress)
- ✅ Single-level subdomains (Cloudflare compatible)
- ✅ Health checks on all deployments
- ✅ Resource limits defined
- ✅ RBAC scoped to namespace
