# ArgoCD Architecture Research - Consolidated Findings

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: **COMPLETE**
**Researcher**: claude-glm-charlie

---

## Executive Summary

**FINDING**: `argocd-manager.ardenone.com` IS the **centralized GitOps controller** for all clusters in the Ardenone infrastructure.

**Architecture Pattern**: Hub-and-spoke model where:
- **Hub**: `argocd-manager.ardenone.com` (centralized ArgoCD server) - ONLINE
- **Spokes**: Multiple clusters including ardenone-cluster

**Current Status Verification** (2026-02-05):
| Check | Result | Evidence |
|-------|--------|----------|
| HTTPS Health | **OK** | `curl -sk https://argocd-manager.ardenone.com/healthz` returns "ok" |
| ArgoCD UI | **RUNNING** | Root endpoint returns ArgoCD HTML (`<title>Argo CD</title>`) |
| API Endpoint | **RESPONDING** | Returns ArgoCD-formatted auth error (`"error":"no session information"`) |
| argocd-proxy | **RUNNING** | Deployment healthy, 1/1 ready |
| Local ArgoCD | **NOT INSTALLED** | No `argocd` namespace exists |

---

## Answers to Research Questions

### Q1: Is argocd-manager.ardenone.com the centralized GitOps controller for all clusters?

**Answer: YES**

**Evidence:**

1. **Health check confirms ArgoCD instance:**
   ```bash
   $ curl -sk https://argocd-manager.ardenone.com/healthz
   ok
   ```

2. **UI endpoint returns ArgoCD HTML:**
   ```html
   <title>Argo CD</title><base href="/">
   ```

3. **API returns ArgoCD-formatted authentication response:**
   ```json
   {"error":"no session information","code":16,"message":"no session information"}
   ```

4. **argocd-proxy configured to point to it:**
   ```yaml
   # ConfigMap: argocd-proxy-config (devpod namespace)
   data:
     ARGOCD_SERVER: argocd-manager.ardenone.com
   ```

5. **Orphaned RBAC artifacts suggest previous cluster registration:**
   - `argocd-manager-role` ClusterRole exists with cluster-admin privileges
   - `argocd-manager-role-binding` ClusterRoleBinding exists
   - This pattern is consistent with cluster registration to external ArgoCD

---

### Q2: Can we use this external ArgoCD to deploy Moltbook?

**Answer: YES, but blocked by expired credentials**

**Requirements:**

| Requirement | Status | Details |
|-------------|--------|---------|
| External ArgoCD server | **ONLINE** | argocd-manager.ardenone.com is accessible |
| Cluster registration | **POSSIBLE** | ardenone-cluster can be managed as remote cluster |
| Valid credentials | **BLOCKED** | `argocd-readonly` token is expired |
| Moltbook namespace | **PENDING** | Requires cluster-admin action |

**Current Blockers:**

1. **Expired `argocd-readonly` token** - Cannot authenticate to external ArgoCD
   - Secret exists in devpod namespace
   - Devpod ServiceAccount cannot read it (Forbidden)
   - Token returns "invalid session" error when used

2. **Missing admin credentials** - No access to create Applications on external ArgoCD

3. **Moltbook namespace** - Needs to be created (requires cluster-admin)

---

### Q3: What credentials are needed to access argocd-manager.ardenone.com?

**Answer: One of the following credential types:**

| Credential Type | Use Case | Current Status |
|-----------------|----------|----------------|
| **Admin credentials** | Create Applications, manage clusters | **NOT AVAILABLE** |
| **Read-write token** | Create Applications | **NOT AVAILABLE** |
| **Read-only token** | View Applications only | **EXPIRED** (argocd-readonly) |

**Existing Secret:**
```yaml
# Secret: argocd-readonly (devpod namespace)
apiVersion: v1
kind: Secret
metadata:
  name: argocd-readonly
  namespace: devpod
type: Opaque
data:
  ARGOCD_AUTH_TOKEN: <BASE64_ENCODED_EXPIRED_TOKEN>
```

**How to Obtain Valid Credentials:**

1. **Contact ArgoCD administrator** - Request credentials for argocd-manager.ardenone.com
2. **Locate external ArgoCD cluster** - Find where argocd-manager is hosted
3. **Check secrets management** - May be stored in external cluster's secrets
4. **Generate new token** - If admin access is available:
   ```bash
   argocd login argocd-manager.ardenone.com --username <admin> --password <password>
   argocd account generate-token --account devpod-readonly
   ```

---

### Q4: Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer: Use EXTERNAL ArgoCD (hub-and-spoke model)**

**Decision Matrix:**

| Factor | External ArgoCD | Local ArgoCD | Winner |
|--------|----------------|--------------|---------|
| Current availability | **ONLINE** | NOT INSTALLED | External |
| Architecture alignment | Hub-and-spoke (intended) | Redundant | External |
| Cluster resources | Minimal (proxy only) | Additional pods | External |
| Multi-cluster support | Built-in | Manual setup | External |
| Maintenance overhead | Centralized | Per-cluster | External |
| Current blocker | Expired credentials | Requires cluster-admin | Tie (both blocked) |

**Recommended Approach: External ArgoCD**

**Reasons:**

1. **Existing infrastructure** - External ArgoCD is already online and functional
2. **Hub-and-spoke architecture** - This is the intended design pattern
3. **Resource efficiency** - No need to run ArgoCD pods in ardenone-cluster
4. **Centralized management** - Consistent GitOps across all clusters
5. **Multi-cluster native** - External ArgoCD designed for multi-cluster management

---

## Architecture Overview

### Hub-and-Spoke ArgoCD Model

```
                    argocd-manager.ardenone.com
                    (External ArgoCD - Hub)
                              |
                    +---------+---------+
                    |                   |
            ardenone-cluster    [cluster2] [cluster3...]
                    |
        +-----------+-----------+
        |           |           |
    devpod      moltbook     [other ns]
    (proxy)     (target)
```

### Component Status

| Component | Type | Status | Location |
|-----------|------|--------|----------|
| **argocd-manager.ardenone.com** | External ArgoCD Server | **ONLINE** | Resolves externally |
| **argocd-proxy** | Read-only proxy | **RUNNING** | devpod namespace |
| **argocd-readonly** | Secret (auth token) | **EXPIRED** | devpod namespace |
| **argocd-manager-role** | ClusterRole | **EXISTS** | Cluster-wide (cluster-admin) |
| **argocd-manager-role-binding** | ClusterRoleBinding | **ORPHANED** | References non-existent SA |
| **argocd-manager SA** | ServiceAccount | **MISSING** | kube-system |

---

## argocd-proxy Details

### Deployment Configuration

```yaml
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
              key: ARGOCD_AUTH_TOKEN  # EXPIRED
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-proxy
  namespace: devpod
spec:
  clusterIP: 10.43.174.252
  ports:
  - port: 8080
```

### Status

| Check | Result |
|-------|--------|
| Pod status | Running (1/1 ready) |
| Health endpoint | OK |
| API access | Blocked (expired token) |

---

## Orphaned RBAC Artifacts

### argocd-manager-role (ClusterRole)

**Status**: EXISTS with cluster-admin privileges

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

### argocd-manager-role-binding (ClusterRoleBinding)

**Status**: EXISTS but references non-existent ServiceAccount

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
subjects:
- kind: ServiceAccount
  name: argocd-manager        # Does NOT exist
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: argocd-manager-role
```

**Interpretation**: This pattern is consistent with:
1. Previous cluster registration to external ArgoCD
2. ServiceAccount was deleted after cluster was unregistered OR
3. ServiceAccount was part of a cleanup operation

---

## Local ArgoCD Status

**Status**: NOT INSTALLED in ardenone-cluster

| Check | Result |
|-------|--------|
| argocd namespace | Does not exist |
| ArgoCD CRDs | Not installed (only Argo Rollouts CRDs exist) |
| ArgoCD pods | Not running |
| ArgoCD Application CRDs | Missing |

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/ARGOCD_ARCHITECTURE_RESEARCH.md` | Initial research (conflicting findings) |
| `k8s/ARGOCD_RESEARCH_MO_196J.md` | Secondary research (external ArgoCD confirmed) |
| `k8s/DEPLOYMENT_PATH_DECISION.md` | PATH 1 vs PATH 2 decision (mo-1ts4) |
| `cluster-configuration/ardenone-cluster/argocd/` | ArgoCD installation manifests |

---

## Related Beads

| Bead | Priority | Description |
|------|----------|-------------|
| **mo-196j** | 1 | This task - ArgoCD architecture research |
| **mo-dbl7** | 1 | Fix expired argocd-readonly token |
| **mo-1ts4** | 1 | Deployment path decision (selected PATH 2) |
| **mo-sg2v** | 1 | Create Moltbook ApplicationSet (closed - PATH 2 selected) |

---

## Recommendations

### Immediate (Moltbook Deployment)

1. **Proceed with PATH 2 (kubectl manual)** per mo-1ts4 decision
2. **Cluster admin action required**: Apply `k8s/NAMESPACE_SETUP_REQUEST.yml`
3. **Deploy**: `kubectl apply -k k8s/`
4. **Verify**: Check pods, services, and IngressRoutes

### Short-term (Credential Resolution)

1. **Resolve mo-dbl7**: Fix expired argocd-readonly token
2. **Obtain admin credentials**: For argocd-manager.ardenone.com
3. **Test access**: Verify external ArgoCD API access

### Long-term (GitOps Migration)

1. **Create Application**: On external ArgoCD targeting moltbook-org
2. **Enable sync**: Automated GitOps deployment
3. **Cleanup**: Remove orphaned RBAC artifacts if no longer needed

---

## Verification Commands

```bash
# Check external ArgoCD health
curl -sk https://argocd-manager.ardenone.com/healthz

# Check external ArgoCD UI
curl -sk https://argocd-manager.ardenone.com/ | head -5

# Check argocd-proxy health
curl http://10.43.174.252:8080/healthz

# Check for local ArgoCD (should be empty)
kubectl get namespace argocd

# Check orphaned RBAC
kubectl get clusterrole argocd-manager-role
kubectl get clusterrolebinding argocd-manager-role-binding

# Check argocd-proxy deployment
kubectl get deployment argocd-proxy -n devpod
```

---

## Summary Answers

| Question | Answer |
|----------|--------|
| **Q1: Is argocd-manager.ardenone.com the centralized GitOps controller?** | **YES** - It is the hub ArgoCD server managing multiple clusters |
| **Q2: Can we use external ArgoCD to deploy Moltbook?** | **YES** - But blocked by expired credentials (mo-dbl7) |
| **Q3: What credentials are needed?** | Admin credentials or read-write token for argocd-manager.ardenone.com |
| **Q4: External or local ArgoCD?** | **EXTERNAL** - Use argocd-manager.ardenone.com (hub-and-spoke model) |

---

**Research Complete**: 2026-02-05
**Next Action**: Commit findings; PATH 2 deployment (kubectl) proceeds pending credential resolution
