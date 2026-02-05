# ArgoCD Architecture Research: External vs Local

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: Complete

---

## Executive Summary

### Key Finding: External ArgoCD EXISTS and Is Functional

**argocd-manager.ardenone.com IS a functioning centralized ArgoCD server**. Investigation confirmed:

1. ✅ **DNS resolution works** - `argocd-manager.ardenone.com` resolves to `10.20.23.100`
2. ✅ **HTTP connection works** - Health check returns HTTP 200 OK
3. ✅ **argocd-proxy is functional** - Returns "OK" on health endpoint at `10.43.174.252:8080`
4. ✅ **API server is responsive** - Returns proper ArgoCD error responses (no session)
5. ⚠️ **Local ArgoCD NOT installed** - No in-cluster ArgoCD instance

### Architecture Decision: External ArgoCD is Viable for Multi-Cluster Management

**argocd-manager.ardenone.com appears to be a centralized GitOps controller** that can manage ardenone-cluster remotely. However, deploying Moltbook requires either:

1. **Option A**: Use external ArgoCD (argocd-manager) to deploy to ardenone-cluster
2. **Option B**: Install local ArgoCD in ardenone-cluster for dedicated control

---

## Architecture Investigation Results

### 1. External ArgoCD (argocd-manager.ardenone.com)

**Status**: ✅ FUNCTIONAL

#### Test Results

| Test | Result | Details |
|------|--------|---------|
| DNS resolution | ✅ PASS | Resolves to `10.20.23.100` |
| HTTP health check | ✅ PASS | `curl -sk https://argocd-manager.ardenone.com/healthz` returns "ok" |
| HTTP/2 support | ✅ PASS | Server responds with HTTP/2 200 |
| API endpoint | ✅ PASS | `/api/v1/applications` returns ArgoCD error (expected - needs auth) |
| Content-Security-Policy | ✅ PASS | Proper headers for web UI |

#### Response Headers

```
HTTP/2 200
accept-ranges: bytes
content-security-policy: frame-ancestors 'self';
content-type: text/html; charset=utf-8
date: Thu, 05 Feb 2026 12:21:21 GMT
vary: Accept-Encoding
x-frame-options: sameorigin
x-xss-protection: 1
content-length: 788
```

#### API Response (Expected - No Auth)

```json
{"error":"no session information","code":16,"message":"no session information"}
```

**Conclusion**: The external ArgoCD server exists and is operational. The API returns a proper authentication error, confirming it is a working ArgoCD instance.

---

### 2. argocd-proxy Deployment

**Status**: ✅ RUNNING and FUNCTIONAL

#### Deployment Details

```yaml
# Deployment: argocd-proxy (devpod namespace)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-proxy
  namespace: devpod
  labels:
    app: argocd-proxy
    purpose: argocd-observability
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
              key: ARGOCD_AUTH_TOKEN
```

#### Status

| Component | Status | Details |
|-----------|--------|---------|
| Pod | ✅ Running | `argocd-proxy-8686d5cb95-*` - 1/1 Ready |
| Service | ✅ Exists | ClusterIP `10.43.174.252:8080` |
| Health check | ✅ OK | `curl http://10.43.174.252:8080/healthz` returns "OK" |
| ConfigMap | ✅ Exists | Points to `argocd-manager.ardenone.com` |
| Secret | ⚠️ Exists | `argocd-readonly` - permissions may be expired |

#### Proxy Configuration

```yaml
# argocd-proxy-config ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-proxy-config
  namespace: devpod
data:
  ARGOCD_SERVER: argocd-manager.ardenone.com
```

#### ArgoCD Tracking Annotation

The proxy deployment has an ArgoCD tracking annotation:
```yaml
annotations:
  argocd.argoproj.io/tracking-id: devpod-ns-ardenone-cluster:apps/Deployment:devpod/argocd-proxy
```

**This indicates the proxy itself is managed by ArgoCD**, likely from the external argocd-manager instance.

**Conclusion**: The argocd-proxy is a read-only proxy that provides access to the external argocd-manager ArgoCD instance. It is functional and being managed by ArgoCD itself.

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

#### Existing Argo Infrastructure (Different Product)

```
# Argo Rollouts CRDs exist (progressive delivery tool)
analysisruns.argoproj.io
analysistemplates.argoproj.io
experiments.argoproj.io
rollouts.argoproj.io

# ArgoCD CRDs are MISSING (GitOps operator)
applications.argoproj.io          # NOT FOUND
appprojects.argoproj.io          # NOT FOUND
applicationsets.argoproj.io      # NOT FOUND
```

**Conclusion**: Argo Rollouts is installed, but ArgoCD (GitOps controller) is NOT installed locally in ardenone-cluster.

---

## Answers to Research Questions

### Q1: Is argocd-manager.ardenone.com a centralized GitOps controller for all clusters?

**Answer**: LIKELY YES.

Evidence:
- ✅ Server is accessible and responsive
- ✅ Returns proper ArgoCD API responses
- ✅ Has HTTP/2, security headers, and proper ArgoCD web UI behavior
- ✅ The argocd-proxy has ArgoCD tracking annotations, suggesting it's managed by external ArgoCD
- ✅ Proxy is configured with read-only credentials

**Architecture Pattern**:
```
┌──────────────────────────────────────────────────────────────────┐
│                    argocd-manager.ardenone.com                   │
│                    (Centralized ArgoCD Server)                   │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │ argocd-server  │  │ repo-server    │  │  application   │    │
│  │   (API + UI)   │  │                │  │   controller   │    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │ Clusters managed:                                       │     │
│  │ - ardenone-cluster (remote)                             │     │
│  │ - apexalgo-iad (possible)                               │     │
│  │ - other clusters (possible)                             │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
                            ▲
                            │ ArgoCD Agent/Push Mode
                            │
┌──────────────────────────────────────────────────────────────────┐
│                    ardenone-cluster                              │
│                                                                  │
│  ┌──────────────────────┐                                       │
│  │   argocd-proxy       │ ← Read-only access to argocd-manager  │
│  │   (devpod namespace) │                                        │
│  └──────────────────────┘                                       │
└──────────────────────────────────────────────────────────────────┘
```

### Q2: Can we use the external ArgoCD to deploy Moltbook?

**Answer**: YES, with proper configuration.

To use external ArgoCD for Moltbook deployment, you need to:

1. **Register ardenone-cluster as a managed cluster** in argocd-manager
2. **Create an Application** in argocd-manager that points to:
   - Repository: `https://github.com/ardenone/moltbook-org.git`
   - Path: `k8s/`
   - Target cluster: ardenone-cluster
   - Target namespace: moltbook

**Configuration Example** (to be created in argocd-manager):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moltbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ardenone/moltbook-org.git
    targetRevision: main
    path: k8s
  destination:
    server: https://10.20.23.100  # ardenone-cluster API server
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Q3: What credentials are needed to access argocd-manager.ardenone.com?

**Answer**: Two types of access:

1. **Read-only access** (via argocd-proxy):
   - Token stored in `argocd-readonly` secret
   - Currently the secret exists but may have expired credentials
   - Access via: `http://argocd-proxy.devpod.svc.cluster.local:8080`

2. **Admin access** (for creating Applications):
   - Need ArgoCD admin credentials for argocd-manager
   - Can access via: `https://argocd-manager.ardenone.com`
   - Requires cluster-admin or ArgoCD admin privileges

**Note**: The existing `argocd-readonly` secret in devpod namespace provides read-only proxy access. To create Applications, you'll need admin access to argocd-manager.

### Q4: Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer**: DEPENDS on requirements.

#### Use External ArgoCD (argocd-manager) if:
- ✅ You want centralized GitOps management across multiple clusters
- ✅ argocd-manager already has ardenone-cluster registered
- ✅ You have admin credentials for argocd-manager
- ✅ You prefer single-pane-of-glass management

**Advantages**:
- Centralized control
- No local resource overhead
- Consistent policies across clusters
- Already operational

**Disadvantages**:
- Network dependency on external server
- Requires credentials management
- Cluster must be registered with argocd-manager

#### Use Local ArgoCD if:
- ✅ You want dedicated, isolated GitOps for ardenone-cluster
- ✅ You don't have admin access to argocd-manager
- ✅ You prefer self-contained deployment
- ✅ You need cluster-admin privileges anyway for other reasons

**Advantages**:
- Full local control
- No external dependencies
- Standard deployment pattern
- Independent operation

**Disadvantages**:
- Requires cluster-admin to install
- Adds resource overhead (~2GB RAM, 2 CPU)
- Separate management plane

---

## Recommended Architecture

### Option 1: External ArgoCD (Recommended if Available)

```
┌─────────────────────────────────────────────────────────────────┐
│               argocd-manager.ardenone.com                       │
│                  (External ArgoCD)                              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Application: moltbook                                   │   │
│  │  - Source: github.com/ardenone/moltbook-org.git         │   │
│  │  - Path: k8s/                                            │   │
│  │  - Target: ardenone-cluster (remote)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ ArgoCD manages remote cluster
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ardenone-cluster                             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              moltbook namespace                          │   │
│  │  - Frontend deployment                                   │   │
│  │  - API deployment                                        │   │
│  │  - Services, IngressRoutes, etc.                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────┐                                               │
│  │ argocd-proxy │ ← Read-only observability                    │
│  └──────────────┘                                               │
└─────────────────────────────────────────────────────────────────┘
```

**Requirements**:
- Admin credentials for argocd-manager
- ardenone-cluster registered as managed cluster
- Network connectivity between argocd-manager and ardenone-cluster

**Implementation Steps**:
1. Obtain admin credentials for argocd-manager
2. Verify ardenone-cluster is registered (or register it)
3. Create Application in argocd-manager pointing to moltbook-org repo
4. Set sync policy and create namespace automatically

---

### Option 2: Local ArgoCD (If External Not Available)

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
│  │  │ - Syncs from: github.com/ardenone/moltbook-org.git │  │   │
│  │  │ - Path: k8s/                                        │  │   │
│  │  │ - Target: moltbook namespace (local)                │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              moltbook namespace                         │   │
│  │  - Frontend deployment                                   │   │
│  │  - API deployment                                        │   │
│  │  - Services, IngressRoutes, etc.                        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Requirements**:
- Cluster-admin access to ardenone-cluster
- RBAC grant to devpod ServiceAccount
- Resources: ~2GB RAM, 2 CPU cores

**Implementation Steps**:
1. Cluster-admin creates ClusterRoleBinding for devpod
2. Install ArgoCD: `kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml`
3. Apply Moltbook Application: `kubectl apply -f k8s/argocd-application.yml`

---

## Implementation Path Forward

### Path A: Use External ArgoCD (Preferred if available)

1. **Verify cluster registration**:
   ```bash
   # Check if ardenone-cluster is registered with argocd-manager
   curl -k https://argocd-manager.ardenone.com/api/v1/clusters \
     -H "Authorization: Bearer <token>"
   ```

2. **Obtain admin credentials** for argocd-manager

3. **Create Application** in argocd-manager UI or via API

4. **Verify deployment**:
   ```bash
   kubectl get all -n moltbook
   ```

### Path B: Install Local ArgoCD (Fallback)

1. **Request cluster-admin action** to apply RBAC:
   ```bash
   kubectl apply -f cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml
   ```

2. **Install ArgoCD**:
   ```bash
   ./k8s/install-argocd.sh
   ```

3. **Deploy Moltbook Application**:
   ```bash
   kubectl apply -f k8s/argocd-application.yml
   ```

4. **Verify deployment**:
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
- **mo-21sg** (P0) - "CRITICAL: Grant cluster-admin to devpod ServiceAccount for ArgoCD installation"

### Documentation Files
- `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml` - RBAC manifest
- `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` - Setup request
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application manifest
- `k8s/install-argocd.sh` - Installation script
- `k8s/ARGOCD_INSTALL_BLOCKER_SUMMARY.md` - Installation blocker details

---

## Verification Commands

### Verify External ArgoCD is Accessible
```bash
# DNS check (should resolve to 10.20.23.100)
getent hosts argocd-manager.ardenone.com

# HTTP health check (should return "ok")
curl -sk https://argocd-manager.ardenone.com/healthz

# API check (should return auth error, confirming server exists)
curl -sk https://argocd-manager.ardenone.com/api/v1/applications

# Check HTTP headers
curl -skI https://argocd-manager.ardenone.com
```

### Verify argocd-proxy Status
```bash
# Check pod is running
kubectl get pods -n devpod -l app=argocd-proxy

# Check health endpoint (should return "OK")
curl http://10.43.174.252:8080/healthz

# Check configuration
kubectl get configmap argocd-proxy-config -n devpod -o yaml

# Check service
kubectl get svc argocd-proxy -n devpod
```

### Verify Local ArgoCD Status (After Installation)
```bash
# Check namespace
kubectl get namespace argocd

# Check CRDs
kubectl get crd | grep 'applications\|appprojects'

# Check pods
kubectl get pods -n argocd

# Check Moltbook application
kubectl get application moltbook -n argocd
```

---

## Summary Table

| Question | Answer |
|----------|--------|
| Is there an external ArgoCD? | YES - argocd-manager.ardenone.com (10.20.23.100) |
| Is external ArgoCD accessible? | YES - HTTP/2 200, API responsive |
| Can we use external ArgoCD? | YES - if cluster is registered and we have admin credentials |
| Is argocd-proxy functional? | YES - returns OK, proxies to argocd-manager |
| Is local ArgoCD installed? | NO - only Argo Rollouts CRDs exist |
| Recommended approach? | External ArgoCD if available, otherwise local installation |
| What's blocking external? | Need admin credentials for argocd-manager |
| What's blocking local? | Need cluster-admin RBAC grant |

---

## Next Steps

### For External ArgoCD Approach:
1. Contact argocd-manager administrator for admin credentials
2. Verify ardenone-cluster registration status
3. Create Moltbook Application in argocd-manager
4. Configure sync policy and verify deployment

### For Local ArgoCD Approach:
1. Execute cluster-admin action bead **mo-21sg**
2. Run installation script: `./k8s/install-argocd.sh`
3. Apply Moltbook Application: `kubectl apply -f k8s/argocd-application.yml`
4. Verify deployment in `moltbook` namespace

---

**Research Completed**: 2026-02-05
**Researcher**: mo-196j (claude-glm-echo worker)
**Status**: Complete - Both options are viable, choice depends on argocd-manager access

---

## Re-Verification (2026-02-05 12:25 UTC)

**Task**: mo-196j follow-up verification

**Findings**:
1. ✅ **argocd-manager.ardenone.com HTTPS health check passes** - Returns "ok"
2. ❌ **HTTP connection fails** - Server accepts HTTPS only (HTTP returns connection error)
3. ✅ **argocd-proxy is healthy** - Returns "OK" on local health endpoint
4. ⚠️ **API requires authentication** - Returns "no session information" without token
5. ✅ **argocd-manager-role ClusterRole exists** - Bound to argocd-manager SA in kube-system

**Note**: Earlier research incorrectly concluded argocd-manager was down because it only tested HTTP. The server is accessible via HTTPS only.

**Corrected findings**:
- External ArgoCD IS online and functional (HTTPS)
- argocd-proxy is configured correctly and healthy
- Need valid credentials to access external ArgoCD API
- Both external and local ArgoCD options are viable
