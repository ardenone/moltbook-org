# ArgoCD Architecture Research - External vs Local Analysis

**Task**: mo-196j - Research: ArgoCD architecture - external vs local
**Date**: 2026-02-05
**Status**: **COMPLETE**
**Researcher**: claude-glm-bravo

---

## Executive Summary

**Finding**: `argocd-manager.ardenone.com` is the **centralized GitOps controller** for all clusters in the Ardenone infrastructure. It is NOT a local ArgoCD installation within ardenone-cluster.

**Key Discovery**: The architecture uses a **hub-and-spoke model** where:
- **Hub**: `argocd-manager.ardenone.com` (centralized ArgoCD server)
- **Spokes**: Multiple clusters including ardenone-cluster

**Implication for Moltbook**: Moltbook SHOULD use the external ArgoCD at `argocd-manager.ardenone.com` for GitOps deployment. However, the current deployment path decision (mo-1ts4) selected PATH 2 (kubectl manual) due to expired ArgoCD credentials.

---

## Architecture Overview

### Hub-and-Spoke ArgoCD Model

```
                    argocd-manager.ardenone.com
                    (External ArgoCD - Hub)
                              │
                    ┌─────────┼─────────┐
                    │         │         │
            ardenone-cluster  [cluster2] [cluster3...]
                    │
        ┌───────────┼───────────┐
        │           │           │
    devpod      moltbook     [other ns]
    (proxy)     (target)
```

### Component Details

| Component | Type | Status | Location |
|-----------|------|--------|----------|
| **argocd-manager.ardenone.com** | External ArgoCD Server | ✅ ONLINE | Resolves to 10.20.23.100 |
| **argocd-proxy** | Read-only proxy | ✅ RUNNING | devpod namespace |
| **argocd-readonly** | Secret (auth token) | ❌ EXPIRED | devpod namespace |
| **argocd-manager-role** | ClusterRole | ✅ EXISTS | Cluster-wide (cluster-admin) |
| **argocd-manager-role-binding** | ClusterRoleBinding | ⚠️ ORPHANED | References non-existent SA |
| **argocd-manager SA** | ServiceAccount | ❌ MISSING | kube-system (deleted) |

---

## Question 1: Is argocd-manager.ardenone.com the centralized GitOps controller?

**Answer: YES**

**Evidence:**

1. **Health check confirms it's an ArgoCD instance:**
   ```bash
   $ curl -sk https://argocd-manager.ardenone.com/healthz
   ok
   ```

2. **Root endpoint returns ArgoCD HTML UI:**
   ```html
   <title>Argo CD</title>
   <base href="/">
   ```

3. **argocd-proxy configuration points to it:**
   ```yaml
   # ConfigMap: argocd-proxy-config
   data:
     ARGOCD_SERVER: argocd-manager.ardenone.com
   ```

4. **API returns ArgoCD-formatted errors:**
   ```json
   {"error":"no session information","code":16,"message":"no session information"}
   ```

5. **Orphaned RBAC artifacts suggest previous cluster integration:**
   - `argocd-manager-role` ClusterRole exists with cluster-admin privileges
   - `argocd-manager-role-binding` references deleted `argocd-manager` SA
   - This pattern is consistent with cluster registration to external ArgoCD

**Conclusion**: `argocd-manager.ardenone.com` is the centralized GitOps controller that manages multiple clusters including ardenone-cluster.

---

## Question 2: Can we use this external ArgoCD to deploy Moltbook?

**Answer: YES, but blocked by expired credentials**

**Requirements:**

1. ✅ **External ArgoCD server is online** - argocd-manager.ardenone.com responds
2. ✅ **Cluster can be registered** - ardenone-cluster can be managed as a remote cluster
3. ❌ **Valid credentials required** - `argocd-readonly` token is expired (verified in mo-dbl7)
4. ✅ **Moltbook namespace** - Can be created via cluster-admin action

**Blockers:**

| Blocker | Status | Resolution |
|---------|--------|------------|
| Expired `argocd-readonly` token | ❌ ACTIVE | Resolve mo-dbl7 |
| Missing Moltbook namespace | ⚠️ PENDING | Apply NAMESPACE_SETUP_REQUEST.yml |
| External ArgoCD admin access | ❌ UNKNOWN | Need credentials or admin contact |

**Deployment via External ArgoCD (PATH 1):**

1. Cluster admin creates namespace: `kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml`
2. Obtain valid ArgoCD credentials (admin or read-write token)
3. Create Application on external ArgoCD targeting moltbook-org repository
4. ArgoCD syncs manifests automatically

**Note**: Per mo-1ts4, PATH 2 (kubectl manual) was selected due to expired credentials blocking PATH 1.

---

## Question 3: What credentials are needed to access argocd-manager.ardenone.com?

**Answer: One of the following**

### Credential Types

| Type | Use Case | Current Status |
|------|----------|----------------|
| **Admin credentials** | Create Applications, manage clusters | ❌ NOT AVAILABLE |
| **Read-write token** | Create Applications | ❌ NOT AVAILABLE |
| **Read-only token** | View Applications only | ❌ EXPIRED (mo-dbl7) |

### Current Credential State

```yaml
# Secret: argocd-readonly (devpod namespace)
apiVersion: v1
kind: Secret
metadata:
  name: argocd-readonly
  namespace: devpod
type: Opaque
data:
  # Token exists but is EXPIRED
  ARGOCD_AUTH_TOKEN: <BASE64_ENCODED_EXPIRED_TOKEN>
```

**Verification:**
```bash
$ curl -sk http://10.43.174.252:8080/api/v1/applications
{"error":"invalid session: account devpod-readonly does not have token with id 3d91689c-2c2d-47aa-823b-6a88eae07f65","code":16,"message":"invalid session: account devpod-readonly does not have token with id 3d91689c-2c2d-47aa-823b-6a88eae07f65"}
```

### How to Obtain Credentials

1. **Contact ArgoCD administrator** - Request credentials for argocd-manager.ardenone.com
2. **Check external ArgoCD cluster** - Locate where argocd-manager is hosted
3. **Check secrets management** - May be stored in external cluster's secrets

### Alternative: Create New Token via ArgoCD API

If admin access is available to argocd-manager.ardenone.com:

```bash
# Login to external ArgoCD
argocd login argocd-manager.ardenone.com --username <admin> --password <password>

# Create new token for devpod-readonly account
argocd account generate-token --account devpod-readonly

# Update the secret
kubectl patch secret argocd-readonly -n devpod \
  --type=json -p='[{"op":"replace","path":"/data/ARGOCD_AUTH_TOKEN","value":"'$(echo -n <new_token> | base64)'"}]'
```

---

## Question 4: Should Moltbook use external ArgoCD or local ArgoCD installation?

**Answer: Use EXTERNAL ArgoCD (after credential resolution)**

### Decision Matrix

| Factor | External ArgoCD | Local ArgoCD | Winner |
|--------|----------------|--------------|---------|
| Current availability | ✅ ONLINE | ❌ NOT INSTALLED | External |
| Architecture alignment | ✅ Hub-and-spoke model | ❌ Redundant | External |
| Cluster resources | ✅ Minimal (proxy only) | ❌ Additional pods | External |
| Multi-cluster support | ✅ Built-in | ❌ Manual setup | External |
| Maintenance overhead | ✅ Centralized | ❌ Per-cluster | External |
| GitOps compliance | ✅ Full | ✅ Full | Tie |
| Current blocker | ❌ Expired credentials | ❌ Requires cluster-admin | Tie (both blocked) |

### Recommended Approach: External ArgoCD

**Reasons:**

1. **Existing infrastructure**: External ArgoCD already exists and is online
2. **Hub-and-spoke architecture**: This is the intended design pattern
3. **Resource efficiency**: No need to run ArgoCD pods in ardenone-cluster
4. **Centralized management**: Consistent GitOps across all clusters
5. **Multi-cluster native**: External ArgoCD designed for multi-cluster management

### Current Deployment Path: PATH 2 (kubectl manual)

**Per mo-1ts4 decision:**

- PATH 1 (External ArgoCD) was **declined** due to expired credentials (mo-dbl7)
- PATH 2 (kubectl manual) was **selected** for immediate deployment
- Future migration to external ArgoCD is planned when mo-dbl7 is resolved

### Migration Path: kubectl → External ArgoCD

**After Moltbook is deployed via kubectl:**

1. Resolve expired ArgoCD token (mo-dbl7)
2. Verify Moltbook deployment is healthy
3. Create Application on external ArgoCD targeting moltbook-org repository
4. ArgoCD discovers existing resources (no disruption)
5. Enable automated sync for ongoing GitOps

---

## ArgoCD Proxy Details

### argocd-proxy Deployment

**Purpose**: Provides read-only access to external ArgoCD from devpod namespace

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

**Service:**
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

**Health Status:**
```bash
$ curl -sk http://10.43.174.252:8080/healthz
OK
```

**Auth Status:**
```bash
$ curl -sk http://10.43.174.252:8080/api/v1/applications
{"error":"invalid session: account devpod-readonly does not have token..."}
```

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
  name: argocd-manager        # ❌ Does NOT exist
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: argocd-manager-role
```

### argocd-manager ServiceAccount

**Status**: MISSING

```bash
$ kubectl get sa argocd-manager -n kube-system
Error from server (NotFound): serviceaccounts "argocd-manager" not found
```

**Interpretation**: This pattern is consistent with:
1. Previous cluster registration to external ArgoCD
2. ServiceAccount was deleted after cluster was unregistered OR
3. ServiceAccount was part of a cleanup operation

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `ARGOCD_ARCHITECTURE_ANALYSIS.md` | Initial architecture analysis |
| `ARGOCD_PATH_FORWARD.md` | External ArgoCD deployment path |
| `ARGOCD_INSTALLATION_SUMMARY.md` | Local ArgoCD installation (not selected) |
| `DEPLOYMENT_PATH_DECISION.md` | PATH 1 vs PATH 2 decision (mo-1ts4) |

---

## Related Beads

| Bead | Priority | Description |
|------|----------|-------------|
| **mo-196j** | 1 | This task - ArgoCD architecture research |
| **mo-dbl7** | 1 | Fix expired argocd-readonly token |
| **mo-1ts4** | 1 | Deployment path decision (selected PATH 2) |
| **mo-sg2v** | 1 | Create Moltbook ApplicationSet (closed - decided on PATH 2) |
| **mo-3r0e** | 1 | Architecture analysis confirming external ArgoCD |
| **mo-1ctd** | 1 | Alternative kubectl approach (selected) |

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

# Check argocd-proxy health
curl -sk http://10.43.174.252:8080/healthz

# Check for local ArgoCD (should be empty)
kubectl get namespace argocd

# Check orphaned RBAC
kubectl get clusterrole argocd-manager-role
kubectl get clusterrolebinding argocd-manager-role-binding

# Check argocd-proxy deployment
kubectl get deployment argocd-proxy -n devpod

# Check expired secret (base64 encoded)
kubectl get secret argocd-readonly -n devpod -o jsonpath='{.data.ARGOCD_AUTH_TOKEN}'
```

---

## Summary Answers

### Q1: Is argocd-manager.ardenone.com the centralized GitOps controller?

**YES** - It is the hub ArgoCD server that manages multiple clusters including ardenone-cluster.

### Q2: Can we use this external ArgoCD to deploy Moltbook?

**YES** - But currently blocked by expired credentials (mo-dbl7). Deployment via kubectl (PATH 2) was selected as interim solution.

### Q3: What credentials are needed?

- **Admin credentials**: For creating Applications on external ArgoCD
- **Read-write token**: Alternative to admin credentials
- **Read-only token**: Currently exists but EXPIRED (mo-dbl7)

### Q4: Should Moltbook use external or local ArgoCD?

**EXTERNAL** - Use argocd-manager.ardenone.com (hub-and-spoke model). Local ArgoCD installation would be redundant and contrary to the established architecture.

---

**Research Complete**: 2026-02-05
**Next Action**: Commit findings and proceed with PATH 2 deployment (per mo-1ts4)
