# ArgoCD Architecture Research Summary - February 2026

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: **COMPLETE**
**Worker**: claude-glm-foxtrot

---

## Executive Summary

### Finding: argocd-manager.ardenone.com IS the centralized GitOps controller

**VERIFIED FACTS** (as of 2026-02-05):

| Check | Status | Details |
|-------|--------|---------|
| DNS resolution | ✅ PASS | Resolves to `10.20.23.100` |
| HTTP health check | ✅ PASS | Returns HTTP 200 "ok" |
| argocd-proxy | ✅ RUNNING | Pod: `argocd-proxy-8686d5cb95-d5tvk` (1/1 Ready) |
| Proxy health | ✅ OK | `10.43.174.252:8080/healthz` returns "OK" |
| Local ArgoCD | ❌ NOT INSTALLED | No `argocd` namespace |

---

## Research Questions Answered

### 1. Is argocd-manager.ardenone.com the centralized GitOps controller?

**Answer: YES**

**Evidence:**
- DNS resolution: `argocd-manager.ardenone.com → 10.20.23.100`
- Health endpoint: `https://argocd-manager.ardenone.com/healthz` returns "ok"
- argocd-proxy configured to point to `argocd-manager.ardenone.com`
- Proxy has ArgoCD tracking annotation: `argocd.argoproj.io/tracking-id`

**Architecture Pattern** (Hub-and-Spoke):
```
argocd-manager.ardenone.com (Hub)
        |
        v
ardenone-cluster (Spoke)
        |
        +-- devpod/argocd-proxy (read-only observability)
```

### 2. Can we use the external ArgoCD to deploy Moltbook?

**Answer: YES, but blocked by credentials**

**Blockers:**
1. ❌ **Expired token** - `argocd-readonly` secret contains invalid/expired token
2. ❌ **No admin access** - Need credentials to create Applications on argocd-manager
3. ⚠️ **Cluster registration** - Need to verify ardenone-cluster is registered

**Per mo-1ts4**: PATH 2 (kubectl manual) was selected due to credential expiration blocking PATH 1.

### 3. What credentials are needed to access argocd-manager.ardenone.com?

**Required:**

| Credential Type | Use Case | Current Status |
|----------------|----------|----------------|
| Admin credentials | Create Applications, manage clusters | ❌ NOT AVAILABLE |
| Read-write token | Create Applications | ❌ NOT AVAILABLE |
| Read-only token | View Applications only | ❌ EXPIRED (mo-dbl7) |

**Current Secret State:**
- Secret: `argocd-readonly` in `devpod` namespace
- Key: `ARGOCD_AUTH_TOKEN`
- Status: Token exists but returns "invalid session" error

### 4. Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer: EXTERNAL ArgoCD (after credential resolution)**

**Decision Matrix:**

| Factor | External ArgoCD | Local ArgoCD | Winner |
|--------|----------------|--------------|---------|
| Availability | ✅ ONLINE | ❌ NOT INSTALLED | External |
| Architecture | ✅ Hub-and-spoke | ❌ Redundant | External |
| Resources | ✅ Minimal | ❌ +2GB RAM, +2 CPU | External |
| Multi-cluster | ✅ Built-in | ❌ Manual | External |
| Current blocker | ❌ Credentials | ❌ Cluster-admin | Tie |

**Recommendation:**
- **Short-term**: PATH 2 (kubectl manual) - per mo-1ts4 decision
- **Long-term**: Migrate to external ArgoCD when mo-dbl7 is resolved

---

## Current Architecture State

### External ArgoCD (argocd-manager.ardenone.com)

```
Status: ONLINE (verified 2026-02-05)
DNS: 10.20.23.100
Health: https://argocd-manager.ardenone.com/healthz → "ok"
```

### argocd-proxy (devpod namespace)

```yaml
Deployment: argocd-proxy
Pod: argocd-proxy-8686d5cb95-d5tvk (1/1 Ready, 2d9h old)
Service: ClusterIP 10.43.174.252:8080
Health: http://10.43.174.252:8080/healthz → "OK"

Environment:
  ARGOCD_SERVER: argocd-manager.ardenone.com (from ConfigMap)
  ARGOCD_AUTH_TOKEN: <from secret argocd-readonly> (EXPIRED)
```

### Orphaned RBAC Artifacts

| Resource | Status | Notes |
|----------|--------|-------|
| `argocd-manager-role` (ClusterRole) | ✅ EXISTS | cluster-admin privileges |
| `argocd-manager-role-binding` | ⚠️ ORPHANED | References non-existent SA in kube-system |
| `argocd-manager` SA | ❌ MISSING | In kube-system |

**Interpretation**: These artifacts suggest previous cluster registration to external ArgoCD, followed by ServiceAccount cleanup.

### Local ArgoCD Status

```
argocd namespace: NOT FOUND
ArgoCD CRDs: NOT INSTALLED (only Argo Rollouts CRDs exist)
Application CRD: NOT FOUND
```

---

## Related Beads

| Bead | Priority | Description |
|------|----------|-------------|
| mo-196j | 1 | This task - ArgoCD architecture research |
| mo-dbl7 | 1 | Fix expired argocd-readonly token |
| mo-1ts4 | 1 | Deployment path decision (selected PATH 2) |
| mo-3r0e | 1 | Architecture analysis confirming external ArgoCD |

---

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz

# Check DNS resolution
getent hosts argocd-manager.ardenone.com

# Check argocd-proxy
kubectl get pods -n devpod -l app=argocd-proxy
curl http://10.43.174.252:8080/healthz

# Check local ArgoCD (should be empty)
kubectl get namespace argocd
kubectl get crd | grep 'applications\.argoproj\.io'

# Check orphaned RBAC
kubectl get clusterrole argocd-manager-role
kubectl get clusterrolebinding argocd-manager-role-binding
kubectl get sa argocd-manager -n kube-system
```

---

## Next Actions

### Immediate (mo-196j completion)
1. ✅ Document findings
2. ✅ Commit research
3. ✅ Create follow-up bead for credential resolution

### Follow-up (mo-dbl7)
1. Resolve expired `argocd-readonly` token
2. Obtain admin credentials for argocd-manager
3. Test API access with valid credentials

### Future (GitOps migration)
1. Resolve mo-dbl7
2. Verify cluster registration
3. Create Application on external ArgoCD
4. Migrate from kubectl to ArgoCD sync

---

**Research Completed**: 2026-02-05
**Commit Message**: feat(mo-196j): Research: ArgoCD architecture - external vs local
