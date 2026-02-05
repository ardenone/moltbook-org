# ArgoCD Architecture Research Addendum: In-Cluster Investigation

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Investigation Context**: In-cluster from devpod on ardenone-cluster

---

## Summary: In-Cluster vs External Access Differences

This addendum captures findings from investigating ArgoCD architecture **from within the devpod** on ardenone-cluster, which differs from external access patterns.

### Key Findings from In-Cluster Investigation

| Aspect | In-Cluster (devpod) | External Access |
|--------|---------------------|-----------------|
| argocd-manager DNS | ❌ No resolution | ✅ Resolves to 10.20.23.100 |
| argocd-proxy health | ✅ "OK" response | N/A |
| argocd-proxy API | ❌ Token invalid | N/A |
| Local ArgoCD | ❌ Not installed | N/A |
| ArgoCD tracking IDs | ✅ Present (managed externally) | N/A |

---

## Detailed Findings

### 1. argocd-proxy Status

**Health**: ✅ Running and healthy
```bash
curl http://argocd-proxy.devpod.svc.cluster.local:8080/healthz
# Returns: OK
```

**API Access**: ❌ Authentication failure
```bash
curl http://argocd-proxy.devpod.svc.cluster.local:8080/api/v1/applications
# Returns: {"error":"invalid session: account devpod-readonly does not have token with id 3d91689c-2c2d-47aa-823b-6a88eae07f65","code":16}
```

**Conclusion**: The proxy is healthy but the devpod-readonly token is invalid/expired.

### 2. ArgoCD Tracking Annotations

The argocd-proxy deployment has ArgoCD tracking annotations, proving it is managed by an external ArgoCD instance:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: devpod-ns-ardenone-cluster:apps/Deployment:devpod/argocd-proxy
```

**This confirms argocd-manager.ardenone.com is managing ardenone-cluster.**

### 3. DNS Resolution

**In-cluster**:
```bash
nslookup argocd-manager.ardenone.com
# Result: Cannot resolve
```

**External**: According to main research document, resolves to 10.20.23.100

**Conclusion**: argocd-manager is accessible from external networks but not from in-cluster DNS. This is expected for a centralized management server.

### 4. Local ArgoCD Status

**Namespace**: Does not exist
```bash
kubectl get namespace argocd
# Error: NotFound
```

**CRDs**: Only Argo Rollouts, no ArgoCD
```bash
kubectl get crd | grep argoproj.io
# Shows: analysisruns, analysistemplates, experiments, rollouts
# Missing: applications, appprojects, applicationsets
```

**Conclusion**: ArgoCD is NOT installed locally in ardenone-cluster.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    External Network                                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          argocd-manager.ardenone.com                         │  │
│  │          (Centralized ArgoCD Server)                         │  │
│  │          - Accessible from external networks                 │  │
│  │          - Manages multiple clusters remotely                │  │
│  │          - DNS: 10.20.23.100                                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                            ▲
                            │ HTTPS / ArgoCD Agent
                            │
┌─────────────────────────────────────────────────────────────────────┐
│                    ardenone-cluster                                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │               devpod namespace                               │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  argocd-proxy Deployment                               │  │  │
│  │  │  - Managed by argocd-manager (tracking ID present)     │  │  │
│  │  │  - Health: OK                                          │  │  │
│  │  │  - Token: Invalid/Expired                              │  │  │
│  │  │  - Provides read-only access to argocd-manager         │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  argocd-readonly Secret                                │  │  │
│  │  │  - Contains expired token                              │  │  │
│  │  │  - Needs refresh from argocd-manager                   │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ❌ NO local ArgoCD installation                                     │
│  ❌ argocd namespace does NOT exist                                   │
│  ❌ ArgoCD CRDs (Application, AppProject) NOT installed             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Answers to Research Questions (In-Cluster Perspective)

### Q1: Is argocd-manager.ardenone.com a centralized GitOps controller?

**Answer**: YES.

Evidence from in-cluster investigation:
- argocd-proxy has ArgoCD tracking annotations
- argocd-proxy is configured to connect to argocd-manager.ardenone.com
- Proxy is healthy and managed externally

### Q2: Can we use external ArgoCD to deploy Moltbook?

**Answer**: POSSIBLY, requires token refresh.

Blockers:
- devpod-readonly token is invalid/expired
- Need to regenerate token from argocd-manager
- Need to verify ardenone-cluster is registered

### Q3: What credentials are needed?

**Answer**: Valid ArgoCD token for devpod-readonly account.

Current state:
- Secret exists but token is invalid
- Need argocd-manager admin access to refresh token

### Q4: Should Moltbook use external or local ArgoCD?

**Answer**: LOCAL ArgoCD is recommended.

Reasons:
- External ArgoCD requires token refresh (need admin access)
- Local ArgoCD provides self-contained deployment
- Already have cluster-admin RBAC request prepared

---

## Recommendations

### Option A: Local ArgoCD (Recommended)

Install ArgoCD locally in ardenone-cluster:
- Full control over GitOps configuration
- No external credential dependency
- Self-healing and drift detection
- Standard deployment pattern

**Prerequisite**: Cluster-admin must apply `CLUSTER_ADMIN_ACTION.yml`

### Option B: Use External ArgoCD (Requires Admin Access)

Use argocd-manager.ardenone.com:
- Need admin credentials for argocd-manager
- Need to refresh devpod-readonly token
- Need to verify ardenone-cluster registration

---

## Related Files

- Main research: `docs/ARGOCD_ARCHITECTURE_RESEARCH.md`
- RBAC request: `cluster-configuration/ardenone-cluster/argocd/CLUSTER_ADMIN_ACTION.yml`
- Installation script: `k8s/install-argocd.sh`
- Application manifest: `k8s/argocd-application.yml`

---

**Investigation Completed**: 2026-02-05
**Investigator**: mo-196j (claude-glm worker)
**Context**: In-cluster investigation from devpod on ardenone-cluster
