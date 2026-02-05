# ArgoCD Sync Verification Report - Moltbook Deployment

**Task**: mo-orzh - Verify: ArgoCD sync for Moltbook deployment
**Date**: 2026-02-05
**Status**: BLOCKED - External ArgoCD sync cannot be verified due to expired credentials
**Worker**: claude-glm (zai-bravo)

---

## Executive Summary

The external ArgoCD at `argocd-manager.ardenone.com` is **healthy and accessible**, but the Moltbook ApplicationSet sync status **cannot be verified** due to:

1. **Expired argocd-proxy token** - The `argocd-readonly` secret contains an invalid token
2. **No evidence of sync** - No ArgoCD-managed Moltbook resources exist in the cluster
3. **moltbook namespace does not exist** - Primary indicator that sync has not occurred

### Primary Blocker

**ArgoCD credentials at external ArgoCD manager are expired**. The `argocd-readonly` secret in the `devpod` namespace contains an invalid token that cannot query the external ArgoCD API.

---

## Verification Results

| Check | Status | Details |
|-------|--------|---------|
| External ArgoCD Health | ✅ Pass | `https://argocd-manager.ardenone.com/healthz` returns "ok" |
| argocd-proxy Pod | ✅ Running | `argocd-proxy-8686d5cb95-d5tvk` is healthy |
| argocd-proxy Service | ✅ Up | `10.43.174.252:8080` responding |
| argocd-readonly Token | ❌ Expired | API returns "invalid session" error |
| moltbook namespace | ❌ Not Found | Does not exist in cluster |
| ArgoCD-managed Moltbook resources | ❌ None | No resources with `argocd.argoproj.io/tracking-id` containing "moltbook" |
| Local ArgoCD CRDs | ❌ Not Installed | `applications.argoproj.io` CRD does not exist |

---

## Evidence

### 1. External ArgoCD Health Check

```bash
$ curl -sk https://argocd-manager.ardenone.com/healthz
ok
```

**Result**: External ArgoCD is online and healthy.

### 2. argocd-proxy Status

```bash
$ kubectl get deployment argocd-proxy -n devpod
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
argocd-proxy    1/1     1            1           48d

$ kubectl get svc argocd-proxy -n devpod
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
argocd-proxy    ClusterIP   10.43.174.252   <none>        8080/TCP   48d
```

**Result**: argocd-proxy is running and accessible.

### 3. ArgoCD API Query Attempt

```bash
$ curl -s http://10.43.174.252:8080/api/v1/applications
{"error":"invalid session: account devpod-readonly does not have token with id 3d91689c-2c2d-47aa-823b-6a88eae07f65","code":16}
```

**Result**: Token is expired/invalid. Cannot query applications.

### 4. moltbook Namespace Check

```bash
$ kubectl get namespace moltbook
Error from server (NotFound): namespaces "moltbook" not found
```

**Result**: Namespace does not exist - primary indicator that ArgoCD has not synced the application.

### 5. ArgoCD-Managed Resources Check

Searched for ArgoCD tracking IDs containing "moltbook":
- **Result**: No resources found

The tracking ID format observed for devpod-managed resources:
- `devpod-ns-ardenone-cluster:apps/Deployment:devpod/argocd-proxy`

Expected format for Moltbook (if synced):
- `moltbook-ns-ardenone-cluster:...` or `moltbook-ardenone-cluster:...`

### 6. Local ArgoCD CRD Check

```bash
$ kubectl get applications.argoproj.io -A
error: the server doesn't have a resource type "applications"

$ kubectl get applicationsets.argoproj.io -A
error: the server doesn't have a resource type "applicationsets"
```

**Result**: ArgoCD CRDs are not installed locally. This is expected - the architecture uses external ArgoCD.

---

## Expected ApplicationSet Configuration

Based on the existing ArgoCD Application manifest (`k8s/argocd-application.yml`), the expected configuration would be:

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
    server: https://kubernetes.default.svc
    namespace: moltbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Note**: This manifest requires the `argocd` namespace to exist, which does not exist in the cluster. The external ArgoCD would manage this as a remote cluster.

---

## Architecture Context

```
argocd-manager.ardenone.com (External ArgoCD)
    |
    | (manages multiple clusters via ApplicationSets)
    |
    +-- ardenone-cluster (this cluster)
         |
         +-- devpod namespace
         |    +-- argocd-proxy (read-only proxy)
         |
         +-- moltbook namespace (DOES NOT EXIST - expected to be created by ArgoCD)
```

---

## Blockers Identified

### Blocker 1: Expired ArgoCD Credentials (P0)

The `argocd-readonly` secret contains an expired token.

**Impact**: Cannot verify ApplicationSet sync status via API

**Resolution Required**: Update the `argocd-readonly` secret with a fresh token from `argocd-manager.ardenone.com`

### Blocker 2: ApplicationSet Not Created (P0)

No evidence that the Moltbook ApplicationSet has been created at the external ArgoCD.

**Impact**: ArgoCD cannot sync the Moltbook deployment

**Resolution Required**: Create ApplicationSet at external ArgoCD targeting:
- Repository: `https://github.com/ardenone/moltbook-org.git`
- Path: `k8s`
- Destination Cluster: `ardenone-cluster`
- Destination Namespace: `moltbook`

### Blocker 3: No Local ArgoCD CRDs (Expected)

ArgoCD CRDs are not installed locally in ardenone-cluster.

**Impact**: Cannot create Application manifests locally

**Note**: This is the expected architecture - external ArgoCD manages multiple clusters. Local CRDs are not required.

---

## Next Steps

### Option 1: Refresh ArgoCD Credentials (Recommended for verification)

1. Obtain fresh `argocd-readonly` token from `argocd-manager.ardenone.com` admin
2. Update the `argocd-readonly` secret in `devpod` namespace
3. Query applications via proxy: `curl http://10.43.174.252:8080/api/v1/applications`
4. Verify if `moltbook-ns-ardenone-cluster` or similar Application exists

### Option 2: Direct Access to External ArgoCD UI/API

1. Access `https://argocd-manager.ardenone.com` directly
2. Navigate to Applications or ApplicationSets
3. Search for `moltbook` or `ardenone-cluster`
4. Verify sync status

### Option 3: Create ApplicationSet at External ArgoCD

If the ApplicationSet doesn't exist, create it with the following configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: moltbook-ardenone-cluster
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: ardenone-cluster
        url: https://kubernetes.default.svc
  template:
    metadata:
      name: moltbook-{{cluster}}
    spec:
      project: default
      source:
        repoURL: https://github.com/ardenone/moltbook-org.git
        targetRevision: main
        path: k8s
      destination:
        server: {{url}}
        namespace: moltbook
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## Related Files

| File | Purpose |
|------|---------|
| `k8s/argocd-application.yml` | Application manifest (for reference) |
| `k8s/ARGOCD_ARCHITECTURE_ANALYSIS.md` | Architecture documentation |
| `cluster-configuration/ardenone-cluster/argocd/` | ArgoCD installation files (not needed for external) |

---

## Related Beads

| Bead ID | Title | Priority | Status |
|---------|-------|----------|--------|
| mo-orzh | Verify: ArgoCD sync for Moltbook deployment | 1 | BLOCKED - This task |
| mo-3ttq | Deploy: Complete Moltbook deployment to ardenone-cluster | 1 | BLOCKED - Namespace creation |
| mo-2c67 | Blocker: Cluster Admin needed - Apply RBAC for Moltbook namespace creation | 0 | NEW - Created by mo-3ttq |
| mo-1fgm | CRITICAL: Install ArgoCD in ardenone-cluster | 1 | BLOCKED - RBAC |

---

## Conclusion

**Status**: CANNOT VERIFY - ArgoCD sync status cannot be determined due to expired credentials

**Key Findings**:
1. External ArgoCD at `argocd-manager.ardenone.com` is healthy and accessible
2. The argocd-proxy is running but uses an expired token
3. No ArgoCD-managed Moltbook resources exist in the cluster
4. The moltbook namespace does not exist (strong evidence that sync has not occurred)

**Recommended Action**:
1. Refresh the `argocd-readonly` secret with a fresh token
2. Query the external ArgoCD API to verify ApplicationSet status
3. If ApplicationSet doesn't exist, create it at the external ArgoCD

---

**Last Updated**: 2026-02-05 09:50 UTC
**Verified by**: mo-orzh (claude-glm-zai-bravo), mo-3ttq (claude-glm-bravo)
**Status**: 🔴 BLOCKED - Requires fresh ArgoCD credentials AND RBAC for namespace creation
