# Moltbook Deployment Blocker Summary

**Status:** BLOCKED - Namespace Creation Requires Cluster Admin
**Date:** 2026-02-04
**Bead:** mo-saz (Implementation: Deploy Moltbook platform to ardenone-cluster)
**New Blocker Bead:** mo-382

---

## Summary

All Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster are **complete and validated**. The deployment is blocked because the `devpod` ServiceAccount lacks permission to create namespaces at the cluster level.

---

## Current State

### Complete Components ✅

| Component | Status | Notes |
|-----------|--------|-------|
| Namespace Manifest | ✅ Ready | `k8s/namespace/moltbook-namespace.yml` |
| RBAC Manifests | ✅ Ready | `k8s/namespace/moltbook-rbac.yml` |
| SealedSecrets | ✅ Ready | 3 encrypted secrets (API, DB, Postgres) |
| PostgreSQL (CNPG) | ✅ Ready | Cluster manifest with 10Gi storage |
| Redis | ✅ Ready | Deployment and Service |
| API Backend | ✅ Ready | 2 replicas, health checks, migrations |
| Frontend | ✅ Ready | 2 replicas, Next.js 14 |
| IngressRoutes | ✅ Ready | Traefik routes for both domains |
| Middlewares | ✅ Ready | CORS, rate limiting, security headers |
| Kustomization | ✅ Validated | Builds 1050 lines successfully |

### Container Images Referenced

- **API:** `ghcr.io/ardenone/moltbook-api:latest`
- **Frontend:** `ghcr.io/ardenone/moltbook-frontend:latest`

---

## Blocker Details

### Error Message

```
Error: namespaces is forbidden: User "system:serviceaccount:devpod:default"
cannot create resource "namespaces" at cluster scope
```

### Root Cause

The `devpod` ServiceAccount does not have the `create` verb on `namespaces` resources.

---

## Resolution Steps

### For Cluster Administrator

**Step 1:** Apply the RBAC manifest (one-time setup)

```bash
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- `ClusterRole`: namespace-creator
- `ClusterRoleBinding`: devpod-namespace-creator

**Step 2:** Verify the RBAC is applied

```bash
kubectl get clusterrolebinding devpod-namespace-creator
```

**Step 3:** Notify the devpod team that RBAC is applied

---

### For DevPod Team (After RBAC Applied)

**Step 1:** Deploy the application

```bash
cd /home/coder/Research/moltbook-org
kubectl apply -k k8s/
```

**Step 2:** Verify deployment

```bash
# Check pods
kubectl get pods -n moltbook

# Check services
kubectl get svc -n moltbook

# Check ingress
kubectl get ingressroutes -n moltbook
```

**Step 3:** Test endpoints

```bash
# API health check
curl https://api-moltbook.ardenone.com/health

# Frontend
curl https://moltbook.ardenone.com
```

---

## Related Beads

### New Consolidated Blocker
- **mo-382** (Priority 0): Fix: Apply RBAC for Moltbook deployment - namespace creation blocked

### Duplicate P0 Beads to Close
The following beads are now superseded by mo-382 and can be closed:
- mo-hfs: Fix: Create moltbook namespace - requires cluster-admin
- mo-3rs: Fix: Grant devpod namespace creation permissions or create moltbook namespace
- mo-3uo: Blocker: Apply RBAC for Moltbook namespace creation
- mo-32c: Create moltbook namespace in ardenone-cluster
- mo-drj: Fix: Create moltbook namespace in ardenone-cluster
- mo-hv4: Fix: Create moltbook namespace in ardenone-cluster
- mo-3iz: Infra: Create moltbook namespace in ardenone-cluster
- mo-2fr: Fix: Create moltbook namespace in ardenone-cluster
- mo-bai: Fix: Create moltbook namespace and RBAC in ardenone-cluster
- mo-272: Deploy: Apply Moltbook manifests to ardenone-cluster

---

## Deployment Architecture (Post-RBAC)

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
  │           ├─ CORS middleware
  │           └─ Rate limiting (100 req/min)
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service (port 80)
          └─ IngressRoute: moltbook.ardenone.com
              └─ Security headers middleware
```

---

## Access Points

- **Frontend:** https://moltbook.ardenone.com
- **API:** https://api-moltbook.ardenone.com
- **API Health:** https://api-moltbook.ardenone.com/health

---

## Files Reference

| Purpose | File |
|---------|------|
| RBAC (requires admin) | `k8s/namespace/devpod-namespace-creator-rbac.yml` |
| Namespace | `k8s/namespace/moltbook-namespace.yml` |
| Kustomization | `k8s/kustomization.yml` |
| PostgreSQL | `k8s/database/cluster.yml` |
| API Deployment | `k8s/api/deployment.yml` |
| Frontend Deployment | `k8s/frontend/deployment.yml` |
| IngressRoutes | `k8s/api/ingressroute.yml`, `k8s/frontend/ingressroute.yml` |
| SealedSecrets | `k8s/secrets/moltbook-*-sealedsecret.yml` |

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

---

**Next Action:** Cluster administrator applies RBAC, then devpod team deploys with `kubectl apply -k k8s/`
