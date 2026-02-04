# Moltbook Deployment Blocker Summary

**Status:** BLOCKED - Namespace Creation Requires Cluster Admin
**Date:** 2026-02-04
**Beads:**
- mo-3tx (CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment)
- mo-saz (Moltbook platform deployment)

## Blocker Summary

**IMPORTANT UPDATE**: External ArgoCD is available at `argocd-manager.ardenone.com` (health check returns "ok").

The task "Install ArgoCD in ardenone-cluster" is based on an incorrect assumption. The **external ArgoCD** should be used instead of installing a local instance.

**Primary Blocker**: The `moltbook` namespace does not exist and cannot be created from the devpod due to RBAC restrictions. A cluster administrator must create the namespace.

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| External ArgoCD | ✅ Online | https://argocd-manager.ardenone.com/healthz returns "ok" |
| argocd-proxy | ✅ Running | devpod namespace (read-only proxy) |
| argocd namespace | ❌ Does Not Exist | Local ArgoCD not installed (not needed) |
| moltbook namespace | ❌ Does Not Exist | Cannot create without cluster-admin |
| ArgoCD Application manifest | ✅ Ready | `k8s/argocd-application.yml` |

### Error Messages

```
Error: customresourcedefinitions.apiextensions.k8s.io is forbidden:
User "system:serviceaccount:devpod:default" cannot create resource "customresourcedefinitions"

Error: namespaces is forbidden: User "system:serviceaccount:devpod:default"
cannot create resource "namespaces" at cluster scope
```

---

## Related Blocker: Namespace Creation (mo-3rs)

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

**Quick Start (One-Command Setup):**

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml
```

This creates:
- `ClusterRole`: namespace-creator
- `ClusterRoleBinding`: devpod-namespace-creator
- `Namespace`: moltbook

**Manual Step-by-Step:**

**Step 1:** Apply the RBAC manifest (one-time setup)

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml
```

This creates:
- `ClusterRole`: namespace-creator
- `ClusterRoleBinding`: devpod-namespace-creator

**Step 2:** Create the moltbook namespace

```bash
kubectl apply -f cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml
```

**Step 3:** Verify the setup

```bash
kubectl get namespace moltbook
kubectl get clusterrolebinding devpod-namespace-creator
```

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

### Active Fix Bead
- **mo-3rs** (Priority 1): Fix: Grant devpod namespace creation permissions or create moltbook namespace
  - Documentation updated to clarify cluster admin requirements
  - Three solution approaches documented (ArgoCD, manual, RBAC)
  - RBAC manifest corrected (Role cannot grant namespace creation)

### Blocked Bead
- **mo-saz** (Priority 2): Implementation: Deploy Moltbook platform to ardenone-cluster
  - Waiting for cluster admin to create namespace or grant permissions

### Related Beads to Close
The following beads may be superseded by mo-3rs:
- mo-hfs: Fix: Create moltbook namespace - requires cluster-admin
- mo-3uo: Blocker: Apply RBAC for Moltbook namespace creation
- mo-32c: Create moltbook namespace in ardenone-cluster
- mo-drj: Fix: Create moltbook namespace in ardenone-cluster
- mo-hv4: Fix: Create moltbook namespace in ardenone-cluster
- mo-3iz: Infra: Create moltbook namespace in ardenone-cluster
- mo-2fr: Fix: Create moltbook namespace in ardenone-cluster
- mo-bai: Fix: Create moltbook namespace and RBAC in ardenone-cluster
- mo-272: Deploy: Apply Moltbook manifests to ardenone-cluster

---

---

## ArgoCD Installation Instructions

### For Cluster Administrator

**Automated Installation (Recommended)**

```bash
cd /home/coder/Research/moltbook-org
./k8s/install-argocd.sh
```

**Manual Installation**

```bash
# Apply the official ArgoCD manifest
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s
```

**Verify Installation**

```bash
./k8s/install-argocd.sh --verify
```

### Post-Installation: Deploy Moltbook

Once ArgoCD is installed, apply the Moltbook Application:

```bash
kubectl apply -f k8s/argocd-application.yml
```

This will:
- Create the `moltbook` namespace automatically
- Deploy all resources from `k8s/` directory via Kustomize
- Keep everything in sync with Git

---

## ArgoCD UI Access

```bash
# Port-forward to ArgoCD API server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login at https://localhost:8080
# Username: admin
# Password: <from command above>
```

---

## Alternative: Direct kubectl Deployment (Non-GitOps)

If ArgoCD installation is delayed, you can deploy directly:

```bash
# Requires namespace creation RBAC (mo-3rs)
kubectl apply -k k8s/
```

**Note:** This bypasses GitOps and requires manual updates for future changes.

---

## Deployment Architecture (Post-ArgoCD)

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
| Namespace Setup Request (all-in-one) | `cluster-configuration/ardenone-cluster/moltbook/namespace/NAMESPACE_SETUP_REQUEST.yml` |
| RBAC (requires admin) | `cluster-configuration/ardenone-cluster/moltbook/namespace/devpod-namespace-creator-rbac.yml` |
| Namespace | `cluster-configuration/ardenone-cluster/moltbook/namespace/moltbook-namespace.yml` |
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

## Related Beads

### Active Blocker Beads
- **mo-2s1** (Priority 0): Fix: Create moltbook namespace in ardenone-cluster
  - Created RBAC and namespace setup manifests
  - Documentation updated with cluster admin action steps
- **mo-27cr** (Priority 0): CRITICAL: RBAC for ArgoCD installation - devpod SA needs cluster-admin
  - Created during mo-3tx execution
  - Documents required RBAC for ArgoCD installation
- **mo-3tx** (Priority 1): CRITICAL: Install ArgoCD in ardenone-cluster for Moltbook deployment
  - Created installation script and documentation

### Previously Documented Blockers
- **mo-3rs** (Priority 1): Fix: Grant devpod namespace creation permissions or create moltbook namespace
  - Namespace creation is now handled by ArgoCD Application (CreateNamespace=true)

### Blocked Beads
- **mo-saz** (Priority 2): Implementation: Deploy Moltbook platform to ardenone-cluster
  - Waiting for ArgoCD installation

---

**Next Action:** Cluster administrator installs ArgoCD using `./k8s/install-argocd.sh`, then applies `k8s/argocd-application.yml`
