# Cluster Admin Action Required: ArgoCD Installation

## Status: 🔴 BLOCKER - Requires Cluster Administrator

### Overview

The Moltbook platform deployment is **blocked** because ArgoCD is not installed in ardenone-cluster. ArgoCD is required for GitOps-based deployment of Moltbook and other applications.

**This is a ONE-TIME setup action.** Once completed, all applications using ArgoCD GitOps will work automatically.

---

## 🚀 Quick Start (For Cluster Admins)

### Install ArgoCD

**Prerequisite**: First, a cluster-admin must create the ClusterRoleBinding:

```bash
# From a cluster-admin workstation:
kubectl create clusterrolebinding devpod-argocd-manager \
  --clusterrole=argocd-manager-role \
  --serviceaccount=devpod:default
```

**Then, from the devpod:**

```bash
# Apply the official ArgoCD manifest
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

### Verify Installation

```bash
# Check ArgoCD pods are running
kubectl get pods -n argocd

# Verify ArgoCD CRDs are installed
kubectl get crd | grep argocd

# Check ArgoCD API server is ready
kubectl get deployment argocd-server -n argocd
```

**Expected output**: All pods should be `Running` or `Completed`, and CRDs should be present.

---

## 📋 What This Installs

The official ArgoCD manifest installs:

### 1. Custom Resource Definitions (CRDs)
- `applications.argoproj.io` - Application CRD for GitOps deployments
- `appprojects.argoproj.io` - Project CRD for logical groupings
- And 15+ other ArgoCD CRDs

### 2. ArgoCD Namespace
- `argocd` namespace for all ArgoCD components

### 3. Core Components
- `argocd-server` - API server and UI
- `argocd-repo-server` - Git repository sync server
- `argocd-application-controller` - Application sync controller
- `argocd-dex-server` - OAuth/OIDC authentication
- `argocd-redis` - Caching layer

---

## 🎯 After Installation

Once ArgoCD is installed, you can deploy the Moltbook Application:

```bash
# Deploy Moltbook via ArgoCD Application
kubectl apply -f k8s/argocd-application.yml
```

ArgoCD will automatically:
- Create the `moltbook` namespace
- Deploy all resources from `k8s/` directory
- Keep everything in sync with Git

---

## 🔒 Security Considerations

### Why This Requires Cluster Admin

- ArgoCD requires **cluster-scoped resources** (CRDs, ClusterRoles)
- CRDs extend the Kubernetes API with new resource types
- Only `cluster-admin` can create cluster-scoped resources
- The devpod ServiceAccount only has **namespace-scoped permissions**

### Resource Requirements

ArgoCD requires:
- **Memory**: ~2GB minimum for production use
- **CPU**: ~1 core minimum
- **Storage**: Not required (stateless components)

---

## 📚 Related Documentation

### In This Repository

- `../moltbook/CLUSTER_ADMIN_ACTION_REQUIRED.md` - Moltbook RBAC setup
- `../moltbook/README.md` - Moltbook deployment guide
- `k8s/argocd-application.yml` - Moltbook ArgoCD Application manifest

### Related Beads

- **mo-1fgm** - Current task: CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- **mo-21wr** (P0) - BLOCKER: ArgoCD installation requires cluster-admin RBAC
- **mo-1te** - Fix Moltbook deployment blocked by RBAC permissions

---

## 🆘 Troubleshooting

### Problem: `kubectl get crd | grep argocd` returns nothing

**Solution**: ArgoCD CRDs were not installed. Re-run:
```bash
kubectl apply -f cluster-configuration/ardenone-cluster/argocd/argocd-install.yml
```

### Problem: Pods stuck in `Pending` or `ImagePullBackOff`

**Solution**: Check pod status and logs:
```bash
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd
kubectl logs <pod-name> -n argocd
```

### Problem: Cannot access ArgoCD UI

**Solution**: You need to create an IngressRoute. Example:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argocd.ardenone.com`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
  tls:
    certResolver: letsencrypt
```

---

## 📞 Contact

For questions or issues:
- Review ArgoCD documentation: https://argo-cd.readthedocs.io/
- Check related beads for investigation history
- Contact the cluster administrator for access

---

**Last Updated**: 2026-02-05 12:59 UTC
**Status**: 🔴 BLOCKER - Awaiting cluster-admin action
**Priority**: P0 (Critical)
**Estimated Time**: 5 minutes (one-time setup)
**Related Beads**:
- mo-1fbe (P0) - CLUSTER-ADMIN ACTION: Create devpod-argocd-manager ClusterRoleBinding
- mo-1fgm - CRITICAL: Install ArgoCD in ardenone-cluster for GitOps deployments
- mo-17ws - CLUSTER-ADMIN ACTION: Install ArgoCD in ardenone-cluster for mo-1fgm
