# ArgoCD Architecture: External vs Local - Summary

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: ✅ Complete

---

## Executive Summary

### Key Finding: External ArgoCD EXISTS and Is ONLINE

**argocd-manager.ardenone.com is a functioning centralized ArgoCD server**.

| Aspect | Finding |
|--------|---------|
| Server | argocd-manager.ardenone.com |
| Health Check | ✅ HTTPS: `curl -sk https://argocd-manager.ardenone.com/healthz` returns "ok" |
| HTTP Access | ❌ HTTP: Connection fails (HTTPS only) |
| API | ✅ Responds with proper ArgoCD auth error (expected behavior) |
| argocd-proxy | ✅ Running in devpod namespace, healthy |

### Architecture Decision for Moltbook

**Two viable options exist for deploying Moltbook:**

1. **External ArgoCD** (argocd-manager.ardenone.com)
   - Centralized GitOps controller
   - Can manage multiple clusters
   - Requires valid credentials (argocd-readonly token may be expired)

2. **Local ArgoCD** (install in ardenone-cluster)
   - Dedicated in-cluster control
   - Requires cluster-admin RBAC
   - Self-contained, no external dependencies

---

## Architecture Diagram

### Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    External Infrastructure                      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │   argocd-manager.ardenone.com (External ArgoCD)          │  │
│  │   - HTTPS: Online (/healthz returns "ok")                │  │
│  │   - HTTP: Not accessible                                 │  │
│  │   - API: Requires authentication                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↓                                     │
│                    (manages clusters)                           │
└───────────────────────────┼─────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                      ardenone-cluster                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              devpod namespace                           │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ argocd-proxy Deployment                            │  │   │
│  │  │ - Status: Running, healthy                         │  │   │
│  │  │ - ARGOCD_SERVER: argocd-manager.ardenone.com       │  │   │
│  │  │ - Token: argocd-readonly (may be expired)          │  │   │
│  │  │ - Service: ClusterIP 10.43.174.252:8080            │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ argocd-manager-role ClusterRole                    │  │   │
│  │  │ - Bound to: argocd-manager SA in kube-system       │  │   │
│  │  │ - Permissions: Full cluster access                 │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         argocd namespace (NOT CREATED YET)              │   │
│  │         - For local ArgoCD installation                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        moltbook namespace (NOT CREATED YET)             │   │
│  │        - For Moltbook deployment                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Research Questions & Answers

### Q1: Is argocd-manager.ardenone.com a centralized GitOps controller for all clusters?

**Answer**: YES (likely)

- Health check returns "ok" via HTTPS
- API returns proper ArgoCD authentication errors
- argocd-proxy is configured to connect to it
- `argocd-manager-role` ClusterRole exists with full cluster permissions

### Q2: Can we use the external ArgoCD to deploy Moltbook?

**Answer**: YES, but requires valid credentials

- The external ArgoCD server is online and responsive
- API requires authentication (returns "no session information" without token)
- `argocd-readonly` secret exists but token may be expired
- Need valid ArgoCD credentials to create Application manifests

### Q3: What credentials are needed to access argocd-manager.ardenone.com?

**Answer**: Valid ArgoCD authentication token

Current state:
- `argocd-readonly` secret exists in devpod namespace
- Token may be expired (API returns "invalid session" error)
- Devpod ServiceAccount cannot read the secret (permission denied)
- Cluster admin has access via `argocd-manager` ServiceAccount in kube-system

### Q4: Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer**: DEPENDS on use case

| Factor | External ArgoCD | Local ArgoCD |
|--------|----------------|--------------|
| Centralized control | ✅ Yes | ❌ No |
| Multi-cluster management | ✅ Yes | ❌ No |
| Dependency on external system | ⚠️ Yes | ✅ No |
| Requires cluster-admin for setup | ⚠️ Maybe | ✅ Yes |
| Credential management | ⚠️ Required | ✅ Self-managed |
| Recommended for Moltbook | ✅ Yes (if credentials work) | ⚠️ Alternative |

**Recommendation**: Use external ArgoCD if valid credentials can be obtained. Otherwise, install local ArgoCD.

---

## Verification Commands

### Verify External ArgoCD is Online
```bash
# Health check (should return "ok")
curl -sk https://argocd-manager.ardenone.com/healthz

# API endpoint (should return auth error)
curl -sk https://argocd-manager.ardenone.com/api/v1/applications
# Expected: {"error":"no session information","code":16,"message":"no session information"}
```

### Verify argocd-proxy Status
```bash
# Check pod is running
kubectl get pods -n devpod -l app=argocd-proxy

# Check health endpoint
curl http://argocd-proxy.devpod.svc.cluster.local:8080/healthz
# Expected: OK

# Check configuration
kubectl get configmap argocd-proxy-config -n devpod -o yaml
# Shows: ARGOCD_SERVER: argocd-manager.ardenone.com
```

### Verify RBAC Configuration
```bash
# Check argocd-manager ClusterRole
kubectl get clusterrole argocd-manager-role -o yaml

# Check who it's bound to
kubectl get clusterrolebinding argocd-manager-role-binding -o yaml
# Shows: ServiceAccount argocd-manager in kube-system namespace
```

---

## Path Forward

### Option 1: Use External ArgoCD (Recommended if credentials work)

1. **Obtain valid credentials** for argocd-manager.ardenone.com
   - Contact cluster admin to renew `argocd-readonly` token
   - Or create new read-only account

2. **Create ArgoCD Application** via external ArgoCD UI/API
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: moltbook
     namespace: argocd  # Created on external ArgoCD
   spec:
     project: default
     source:
       repoURL: https://github.com/ardenone/moltbook-org.git
       targetRevision: main
       path: k8s
     destination:
       server: https://kubernetes.default.svc
       namespace: moltbook
   ```

3. **Create moltbook namespace** (cluster admin action)
   ```bash
   kubectl create namespace moltbook
   ```

### Option 2: Install Local ArgoCD

1. **Apply RBAC** (cluster admin action)
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml
   ```

2. **Install ArgoCD locally**
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
   ```

3. **Create Moltbook Application**
   ```bash
   kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml
   ```

---

## Related Documentation

- `docs/ARGOCD_ARCHITECTURE_RESEARCH.md` - Detailed research findings
- `ARGOCD_BLOCKER_MO_Y5O.md` - Installation blocker details
- `k8s/ARGOCD_PATH_FORWARD.md` - Path forward analysis
- `k8s/ARGOCD_INSTALL_REQUEST.yml` - RBAC manifest for local installation
- `k8s/argocd-application.yml` - Moltbook Application manifest

---

## Summary

| Question | Answer |
|----------|--------|
| Is there an external ArgoCD? | YES - argocd-manager.ardenone.com (HTTPS only) |
| Is it functional? | YES - /healthz returns "ok" |
| Can we use it for Moltbook? | YES - but need valid credentials |
| Should we use external or local? | External if credentials work, otherwise local |
| What's blocking external use? | Valid authentication token needed |
| What's blocking local install? | Cluster-admin RBAC needed |

---

**Research Completed**: 2026-02-05
**Researcher**: mo-196j (claude-glm-golf worker)
**Status**: ✅ Complete - External ArgoCD confirmed online
