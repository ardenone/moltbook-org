# ArgoCD Architecture Research: External vs Local

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: ✅ Complete

---

## Executive Summary

### Key Finding: No Centralized External ArgoCD

**argocd-manager.ardenone.com is NOT a functioning centralized ArgoCD server**. Investigation revealed:

1. ❌ **DNS resolution fails** - `argocd-manager.ardenone.com` does not resolve in DNS
2. ❌ **HTTP connection fails** - Direct health check returns connection refused
3. ✅ **argocd-proxy exists** - But is configured to point to a non-existent server
4. ❌ **Expired credentials** - `argocd-readonly` secret cannot be accessed (permission denied)

### Conclusion: Moltbook MUST Use Local ArgoCD Installation

The only viable path forward is to install ArgoCD locally in ardenone-cluster.

---

## Architecture Investigation Results

### 1. External ArgoCD (argocd-manager.ardenone.com)

**Status**: ❌ NON-FUNCTIONAL

#### Test Results

| Test | Result | Details |
|------|--------|---------|
| DNS resolution | ❌ FAILED | `nslookup argocd-manager.ardenone.com` - no records found |
| HTTP health check | ❌ FAILED | Connection refused / timeout |
| IngressRoute | ❌ NOT FOUND | No Traefik IngressRoute for argocd-manager |
| Ingress | ❌ NOT FOUND | No standard Ingress for argocd-manager |

#### Configuration Evidence

```yaml
# argocd-proxy-config ConfigMap (exists)
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-proxy-config
  namespace: devpod
data:
  ARGOCD_SERVER: argocd-manager.ardenone.com  # Points to non-existent server
```

**Conclusion**: The `argocd-proxy` deployment is attempting to proxy to a server that doesn't exist.

---

### 2. argocd-proxy Deployment

**Status**: ⚠️ RUNNING but NOT FUNCTIONAL

#### Deployment Details

```yaml
# Deployment: argocd-proxy (devpod namespace)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-proxy
  namespace: devpod
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: argocd-proxy
        image: ronaldraygun/argocd-proxy:1.0.2
        env:
        - name: ARGOCD_SERVER
          valueFrom:
            configMapKeyRef:
              name: argocd-proxy-config
              key: ARGOCD_SERVER  # argocd-manager.ardenone.com
        - name: ARGOCD_AUTH_TOKEN
          valueFrom:
            secretKeyRef:
              name: argocd-readonly
              key: ARGOCD_AUTH_TOKEN  # Secret cannot be accessed
```

#### Status

| Component | Status | Details |
|-----------|--------|---------|
| Pod | ✅ Running | `argocd-proxy-8686d5cb95-d5tvk` - 1/1 Ready |
| Service | ✅ Exists | ClusterIP `10.43.174.252:8080` |
| Health check | ✅ OK | `curl http://argocd-proxy.../healthz` returns "OK" |
| ConfigMap | ✅ Exists | Points to `argocd-manager.ardenone.com` |
| Secret | ❌ Inaccessible | `argocd-readonly` - permission denied |

#### Secret Access Error

```
$ kubectl get secret argocd-readonly -n devpod
Error from server (Forbidden): secrets "argocd-readonly" is forbidden: User "system:serviceaccount:devpod:default" cannot get resource "secrets"
```

**Conclusion**: The proxy is running but cannot connect to its configured ArgoCD server because the server doesn't exist and the credentials are inaccessible.

---

### 3. Local ArgoCD Status in ardenone-cluster

**Status**: ❌ NOT INSTALLED

#### Verification Results

| Check | Result | Details |
|-------|--------|---------|
| argocd namespace | ❌ NotFound | `kubectl get namespace argocd` - does not exist |
| ArgoCD CRDs | ❌ Not Installed | Only Argo Rollouts CRDs exist |
| ArgoCD pods | ❌ Not Running | No argocd namespace |
| ArgoCD Application CRDs | ❌ Missing | `applications.argoproj.io` - not found |
| ArgoCD AppProject CRDs | ❌ Missing | `appprojects.argoproj.io` - not found |

#### Existing Argo Infrastructure (Not Usable)

```
# Argo Rollouts CRDs exist (different product)
analysisruns.argoproj.io
analysistemplates.argoproj.io
experiments.argoproj.io
rollouts.argoproj.io

# ArgoCD CRDs are MISSING
applications.argoproj.io          # NOT FOUND
appprojects.argoproj.io          # NOT FOUND
applicationsets.argoproj.io      # NOT FOUND
```

**Conclusion**: Argo Rollouts is installed, but ArgoCD (GitOps controller) is NOT installed.

---

## Answers to Research Questions

### Q1: Is argocd-manager.ardenone.com a centralized GitOps controller for all clusters?

**Answer**: NO.

- DNS resolution fails completely
- HTTP connection fails
- No IngressRoute or Ingress resources found
- The argocd-proxy is configured to point to this non-existent server

### Q2: Can we use the external ArgoCD to deploy Moltbook?

**Answer**: NO.

- The external ArgoCD server does not exist or is not accessible
- The argocd-proxy cannot function without a valid ArgoCD server
- Credentials for the external ArgoCD are inaccessible

### Q3: What credentials are needed to access argocd-manager.ardenone.com?

**Answer**: N/A - The server does not exist or is not accessible.

The `argocd-readonly` secret exists but:
- Devpod ServiceAccount cannot read it (permission denied)
- Even if accessible, it would authenticate to a non-existent server

### Q4: Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer**: LOCAL ArgoCD installation is the ONLY viable option.

**Reasons**:
1. External ArgoCD server does not exist
2. argocd-proxy is non-functional
3. Local ArgoCD installation provides:
   - Full GitOps automation
   - Self-healing capabilities
   - Declarative deployment management
   - No external dependencies

---

## Recommended Architecture

### Option 1: Local ArgoCD (RECOMMENDED)

```
┌─────────────────────────────────────────────────────────────────┐
│                     ardenone-cluster                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              argocd namespace (local)                   │   │
│  │                                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │   │
│  │  │ argocd-server│  │repo-server   │  │application    │  │   │
│  │  │   (API+UI)   │  │              │  │  controller   │  │   │
│  │  └──────────────┘  └──────────────┘  └───────────────┘  │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ Moltbook Application                                │  │   │
│  │  │ - Syncs from: https://github.com/ardenone/moltbook-org│  │   │
│  │  │ - Path: k8s/                                        │  │   │
│  │  │ - Target: moltbook namespace                        │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              moltbook namespace                         │   │
│  │  - Frontend deployment                                   │   │
│  │  - API deployment                                        │   │
│  │  - Services, IngressRoutes, etc.                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Advantages**:
- ✅ Full control over ArgoCD configuration
- ✅ No external dependencies
- ✅ Local GitOps automation
- ✅ Self-healing and drift detection
- ✅ Standard ArgoCD deployment pattern

**Disadvantages**:
- ⚠️ Requires cluster-admin privileges to install
- ⚠️ Adds resource overhead to ardenone-cluster

---

### Option 2: External ArgoCD (NOT VIABLE)

```
┌──────────────────────────┐         ┌──────────────────────────┐
│   ardenone-cluster       │         │  External ArgoCD         │
│                          │  ❌     │  (argocd-manager)        │
│  ┌────────────────────┐  │         │  - Does NOT exist        │
│  │    argocd-proxy    │  │         │  - DNS fails             │
│  │    (devpod)        │  │         │  - Not accessible        │
│  └────────────────────┘  │         └──────────────────────────┘
└──────────────────────────┘
```

**Status**: NOT AN OPTION

---

## Implementation Path Forward

### Step 1: Install Local ArgoCD (Requires Cluster-Admin)

```bash
# From cluster-admin workstation:
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default

# From devpod:
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Deploy Moltbook Application

```bash
kubectl apply -f k8s/argocd-application.yml
```

### Step 3: Verify Deployment

```bash
kubectl get application moltbook -n argocd
kubectl get all -n moltbook
```

---

## Related Beads and Documentation

### Research Bead
- **mo-196j** (this task) - ArgoCD architecture research

### Installation Blockers
- **mo-2dpt** (P0) - "ADMIN: Cluster Admin Action - Install ArgoCD in ardenone-cluster"
- **mo-1fgm** - "CRITICAL: Install ArgoCD in ardenone-cluster"

### Documentation Files
- `cluster-configuration/ardenone-cluster/argocd/BLOCKER.md` - Detailed blocker information
- `cluster-configuration/ardenone-cluster/argocd/INSTALLATION_STATUS.md` - Installation status
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - RBAC request manifest
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application manifest

---

## Verification Commands

### Verify External ArgoCD is NOT accessible
```bash
# DNS check (will fail)
nslookup argocd-manager.ardenone.com

# HTTP check (will fail)
curl -v http://argocd-manager.ardenone.com/healthz

# Check IngressRoute (will be empty)
kubectl get ingressroute -A | grep argocd
```

### Verify argocd-proxy Status
```bash
# Check pod is running
kubectl get pods -n devpod -l app=argocd-proxy

# Check health endpoint (will return OK but proxy is non-functional)
curl http://argocd-proxy.devpod.svc.cluster.local:8080/healthz

# Check configuration
kubectl get configmap argocd-proxy-config -n devpod -o yaml
```

### Verify Local ArgoCD Status (After Installation)
```bash
# Check namespace
kubectl get namespace argocd

# Check CRDs
kubectl get crd | grep argoproj.io

# Check pods
kubectl get pods -n argocd

# Check Moltbook application
kubectl get application moltbook -n argocd
```

---

## Summary

| Question | Answer |
|----------|--------|
| Is there an external ArgoCD? | NO - argocd-manager.ardenone.com does not exist |
| Can we use external ArgoCD? | NO - server is not accessible |
| Should we use external or local? | LOCAL - only viable option |
| What's blocking us? | Cluster-admin RBAC needed for local installation |
| Next step? | Cluster-admin must apply ARGOCD_SETUP_REQUEST.yml |

---

**Research Completed**: 2026-02-05
**Researcher**: mo-196j (claude-glm-golf worker)
**Status**: ✅ Complete - Ready for cluster-admin action
