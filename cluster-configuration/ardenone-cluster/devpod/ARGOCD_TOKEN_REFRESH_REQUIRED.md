# ArgoCD Token Refresh Required - argocd-readonly Secret

**Task**: mo-dbl7 - Fix: Expired argocd-readonly token in devpod namespace
**Date**: 2026-02-05
**Status**: BLOCKED - Requires ArgoCD admin access to argocd-manager.ardenone.com
**Priority**: P0 (Critical)

---

## Summary

The `argocd-readonly` secret in the `devpod` namespace contains an **expired authentication token**. The argocd-proxy deployment cannot authenticate to the external ArgoCD server at `argocd-manager.ardenone.com`.

**API Error**:
```
{"error":"invalid session: account devpod-readonly does not have token with id 3d91689c-2c2d-47aa-823b-6a88eae07f65","code":16}
```

---

## Resolution Steps (Requires ArgoCD Admin Access)

### Step 1: Login to argocd-manager.ardenone.com

From a workstation with `argocd` CLI installed:

```bash
# Login to external ArgoCD
argocd login argocd-manager.ardenone.com --username admin --password <ADMIN_PASSWORD>

# Or via API
curl -sk https://argocd-manager.ardenone.com/api/v1/session \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<ADMIN_PASSWORD>"}'
```

### Step 2: Generate New Token for devpod-readonly Account

**Option A: Generate token for existing account**
```bash
# Check if devpod-readonly account exists
argocd account get --account devpod-readonly

# Generate new token
argocd account generate-token --account devpod-readonly --expires-in 87600h
```

**Option B: Create new account and token**
```bash
# Create the account if it doesn't exist
argocd account create devpod-readonly --account-type readonly

# Generate token
argocd account generate-token --account devpod-readonly --expires-in 87600h
```

**Expected Output**:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 3: Update the Secret in devpod Namespace

From the devpod or ardenone-cluster:

```bash
# Method 1: Using kubectl patch (recommended)
kubectl patch secret argocd-readonly -n devpod \
  --type=json \
  -p='[{"op":"replace","path":"/data/ARGOCD_AUTH_TOKEN","value":"'$(echo -n '<NEW_TOKEN>' | base64)'"}]'

# Method 2: Delete and recreate (if patch fails)
kubectl delete secret argocd-readonly -n devpod
kubectl create secret generic argocd-readonly -n devpod \
  --from-literal=ARGOCD_AUTH_TOKEN='<NEW_TOKEN>'
```

### Step 4: Restart argocd-proxy Deployment

The deployment has Reloader annotations, so it should auto-restart. If not:

```bash
# Force restart
kubectl rollout restart deployment argocd-proxy -n devpod

# Wait for rollout
kubectl rollout status deployment argocd-proxy -n devpod
```

### Step 5: Verify Authentication

```bash
# Test via proxy
curl -s http://10.43.174.252:8080/api/v1/applications

# Expected: JSON array of applications (not error)
# Or empty array if no applications exist: []
```

---

## Current Configuration

### argocd-proxy Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-proxy
  namespace: devpod
spec:
  template:
    metadata:
      annotations:
        secret.reloader.stakater.com/reload: argocd-readonly
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

### Secret Status

```bash
$ kubectl get secret argocd-readonly -n devpod
NAME              TYPE     DATA   AGE
argocd-readonly   Opaque   1      48d

$ curl -s http://10.43.174.252:8080/api/v1/applications
{"error":"invalid session: account devpod-readonly does not have token...","code":16}
```

---

## Architecture

```
argocd-manager.ardenone.com (External ArgoCD Server)
    |
    | (requires valid token)
    |
    v
devpod namespace (ardenone-cluster)
    |
    +-- argocd-proxy Deployment
    |    |
    |    +-- ARGOCD_SERVER: argocd-manager.ardenone.com
    |    +-- ARGOCD_AUTH_TOKEN: <EXPIRED> (from argocd-readonly secret)
    |
    +-- argocd-readonly Secret
         +-- ARGOCD_AUTH_TOKEN: <EXPIRED_TOKEN>
```

---

## Token Expiration Management

To prevent future expirations, generate tokens with extended validity:

```bash
# 10 year expiration (recommended for service accounts)
argocd account generate-token --account devpod-readonly --expires-in 87600h

# Or indefinite token (if supported)
argocd account generate-token --account devpod-readonly
```

---

## Alternative: Token Rotation Script

Create a scheduled job to rotate tokens before expiration:

```bash
#!/bin/bash
# argocd-token-rotation.sh

ARGOCD_SERVER="argocd-manager.ardenone.com"
ACCOUNT="devpod-readonly"
NAMESPACE="devpod"
SECRET_NAME="argocd-readonly"

# Login to ArgoCD
argocd login "$ARGOCD_SERVER" --username admin --password "$ARGOCD_ADMIN_PASSWORD"

# Generate new token
NEW_TOKEN=$(argocd account generate-token --account "$ACCOUNT" --expires-in 87600h)

# Update secret
kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" \
  --type=json \
  -p='[{"op":"replace","path":"/data/ARGOCD_AUTH_TOKEN","value":"'$(echo -n "$NEW_TOKEN" | base64)'"}]'

# Restart proxy
kubectl rollout restart deployment argocd-proxy -n "$NAMESPACE"
```

---

## Related Resources

| Resource | Location | Purpose |
|----------|----------|---------|
| argocd-proxy Deployment | devpod namespace | Read-only proxy to external ArgoCD |
| argocd-proxy-config ConfigMap | devpod namespace | ArgoCD server URL |
| argocd-readonly Secret | devpod namespace | **EXPIRED** authentication token |
| argocd-manager.ardenone.com | External | Centralized ArgoCD server |

---

## Related Beads

| Bead ID | Title | Priority |
|---------|-------|----------|
| **mo-dbl7** | Fix: Expired argocd-readonly token (this task) | P0 |
| mo-sg2v | Create: Moltbook ApplicationSet at external ArgoCD | P0 |
| mo-3ttq | Deploy: Complete Moltbook deployment | P1 |
| mo-orzh | Verify: ArgoCD sync for Moltbook deployment | P1 |

---

## Notes

1. **ArgoCD admin access required**: This task cannot be completed without admin credentials to argocd-manager.ardenone.com
2. **External ArgoCD architecture**: The cluster uses external ArgoCD (hub-and-spoke model), not a local installation
3. **Token expiration**: Tokens typically expire after a set period. Consider using long-lived tokens for service accounts
4. **Reloader annotation**: The deployment has `secret.reloader.stakater.com/reload` annotation, which should auto-restart pods when the secret changes

---

**Last Updated**: 2026-02-05
**Status**: 🔴 BLOCKED - Requires ArgoCD admin credentials
**Action Required**: Contact ArgoCD administrator to refresh devpod-readonly token
