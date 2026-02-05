# ArgoCD Alternative Installation Methods Research

**Bead ID**: mo-1bci
**Task**: Research: Alternative ArgoCD installation methods for ardenone-cluster
**Date**: 2026-02-05
**Status**: COMPLETE
**Researcher**: claude-glm-bravo

---

## Executive Summary

The devpod ServiceAccount lacks cluster-admin to install ArgoCD via manifests. This research evaluates four alternative approaches and provides security and feasibility analysis.

**KEY FINDING**: An **external ArgoCD hub** (`argocd-manager.ardenone.com`) already exists and is the intended GitOps controller for ardenone-cluster. Using this external ArgoCD is the RECOMMENDED approach, but is currently blocked by expired credentials.

---

## Current State Assessment

### Ardenone-Cluster Status (2026-02-05)

| Check | Result |
|-------|--------|
| ArgoCD namespace (`argocd`) | Does NOT exist |
| ArgoCD CRDs | NOT installed |
| ArgoCD pods | NOT running |
| Devpod SA cluster-admin | NO permissions |
| External ArgoCD (`argocd-manager.ardenone.com`) | **ONLINE** |
| argocd-readonly token | **EXPIRED** |

### Devpod ServiceAccount Permissions

The devpod ServiceAccount (`system:serviceaccount:devpod:default`) currently has:
- **NO** cluster-admin privileges
- **NO** ability to create CustomResourceDefinitions (cluster-scoped)
- **NO** ability to create ClusterRole/ClusterRoleBinding (cluster-scoped)
- **NO** ability to create namespaces (cluster-scoped)

Existing bindings for `devpod:default` SA:
- `k8s-observer-devpod-cluster-resources` - Observer permissions only
- `kalshi-volumeattachment-manager` - Namespace-scoped role
- Other namespace-scoped roles (not cluster-admin)

---

## Approach 1: Helm Installation

### Description
Install ArgoCD using Helm from the devpod, if Helm is available and has necessary permissions.

### Assessment

| Factor | Status | Notes |
|--------|--------|-------|
| Helm installed in devpod | **NO** | `helm` command not found |
| Helm permissions | Would require cluster-admin | Same blocker as manifests |
| Feasibility | NOT FEASIBLE | Missing binary + permissions |

### Security Analysis

**Even if Helm were installed**, it would face the same fundamental blocker:
- Helm creates cluster-scoped resources (CRDs, ClusterRoles, ClusterRoleBindings)
- Devpod SA lacks permissions for these operations
- Would still require cluster-admin to grant privileges

### Recommendation

**NOT RECOMMENDED** - Double blocker (missing tool + permissions). Not worth pursuing.

---

## Approach 2: External GitOps via GitHub Actions

### Description
Use GitHub Actions to apply Kubernetes manifests directly to ardenone-cluster, bypassing ArgoCD entirely.

### Architecture

```
GitHub Actions --kubeconfig--> ardenone-cluster API
     |
     v
Apply manifests (kubectl apply)
```

### Assessment

| Factor | Status | Notes |
|--------|--------|-------|
| GitHub Actions infrastructure | **EXISTS** | `.github/workflows/build-images.yml` |
| Kubeconfig for cluster access | **AVAILABLE** | `apexalgo-iad.kubeconfig` exists (different cluster) |
| Credentials for ardenone-cluster | **MISSING** | Would need kubeconfig or token |
| GitOps experience | **SIMPLIFIED** | Direct kubectl apply, no sync loop |

### Security Analysis

**Security Concerns:**

1. **Credential Storage** - Cluster credentials stored in GitHub Secrets
   - Risk: GitHub repo compromise = cluster compromise
   - Mitigation: Use short-lived tokens, GitHub OIDC federation

2. **No Native Sync State** - No built-in drift detection
   - Risk: Manual changes persist unnoticed
   - Mitigation: Periodic validation jobs

3. **Audit Trail** - GitHub Actions logs provide audit, but less granular than ArgoCD

4. **Multi-Cluster** - Would need separate workflow/credentials per cluster

**Advantages:**
- No cluster-admin required (if kubeconfig with deploy permissions exists)
- Simpler infrastructure
- Faster feedback (CI/CD integrated)

**Disadvantages:**
- No built-in sync state management
- Manual drift detection required
- Less mature GitOps pattern

### Feasibility

**BLOCKED** - Requires kubeconfig/credentials for ardenone-cluster with deployment permissions. Currently only have:
- In-cluster access from devpod (limited RBAC)
- `apexalgo-iad.kubeconfig` (for different cluster)

### Recommendation

**CONDITIONAL** - Feasible if:
1. Kubeconfig for ardenone-cluster is available with proper permissions
2. Organization accepts GitHub-hosted GitOps model
3. Team accepts manual drift detection vs ArgoCD's automated sync

---

## Approach 3: Cluster-Admin Manual Installation

### Description
Have a cluster-admin manually install ArgoCD using the prepared manifests.

### Available Manifests

| Manifest | Location | Purpose |
|----------|----------|---------|
| `k8s/ARGOCD_INSTALL_REQUEST.yml` | `/home/coder/Research/moltbook-org/k8s/` | RBAC + namespace setup |
| `cluster-configuration/ardenone-cluster/argocd/ARGOCD_SETUP_REQUEST.yml` | `/home/coder/Research/moltbook-org/cluster-configuration/` | Alternative RBAC setup |
| `cluster-configuration/ardenone-cluster/argocd/argocd-install.yml` | `/home/coder/Research/moltbook-org/` | Full ArgoCD manifest (1.8MB) |

### Installation Steps (Cluster-Admin Only)

```bash
# Option A: Grant devpod permissions to install
kubectl apply -f /home/coder/Research/moltbook-org/k8s/ARGOCD_INSTALL_REQUEST.yml

# Then from devpod:
kubectl apply -f /home/coder/Research/moltbook-org/cluster-configuration/ardenone-cluster/argocd/argocd-install.yml

# Option B: Direct installation by cluster-admin
kubectl create namespace argocd
kubectl create namespace moltbook
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Security Analysis

**Risks:**

1. **Privilege Grant** - `ARGOCD_INSTALL_REQUEST.yml` grants broad permissions to devpod SA
   - Creates ClusterRole with CRD, ClusterRole, ClusterRoleBinding management
   - Effectively near-cluster-admin for ArgoCD operations
   - Risk: Devpod compromise could affect cluster-wide resources

2. **Local ArgoCD Security Surface** - Running ArgoCD pods in-cluster
   - Additional attack surface (more pods to secure)
   - Resource overhead (CPU, memory, storage)
   - Maintenance burden (upgrades, patches)

3. **Redundancy** - Local ArgoCD duplicates external hub functionality
   - Architectural inconsistency with hub-and-spoke model
   - Fragmented GitOps management

**Advantages:**
- Self-contained installation
- Full control over ArgoCD configuration
- No external dependencies

### Feasibility

**FEASIBLE** - Single cluster-admin action required.

**BLOCKER:** Requires cluster-admin availability and approval.

### Recommendation

**NOT RECOMMENDED** - Conflicts with existing hub-and-spoke architecture. Use external ArgoCD instead (Approach 4).

---

## Approach 4: External ArgoCD (Hub-and-Spoke Model) ⭐ RECOMMENDED

### Description

Use the existing external ArgoCD at `argocd-manager.ardenone.com` as the centralized GitOps controller for ardenone-cluster.

### Architecture

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

### Current Status (2026-02-05)

| Component | Status | Evidence |
|-----------|--------|----------|
| External ArgoCD | **ONLINE** | `curl -sk https://argocd-manager.ardenone.com/healthz` returns "ok" |
| ArgoCD UI | **RUNNING** | HTML response with `<title>Argo CD</title>` |
| API Endpoint | **RESPONDING** | Returns auth error (expected without credentials) |
| argocd-proxy | **RUNNING** | Deployment healthy, 1/1 ready |
| argocd-readonly token | **EXPIRED** | Cannot authenticate |

### Security Analysis

**Advantages:**

1. **Centralized Security** - Single point of control
   - Credentials managed at hub
   - Consistent RBAC across clusters
   - Easier audit and compliance

2. **Resource Efficiency** - No ArgoCD pods in ardenone-cluster
   - Reduced attack surface in cluster
   - Lower resource overhead
   - Simpler cluster architecture

3. **Hub-and-Spoke Pattern** - Industry best practice
   - Multi-cluster native design
   - Centralized GitOps management
   - Consistent deployment patterns

4. **Existing Infrastructure** - Already deployed and functional
   - No new installation required
   - Proven architecture

**Risks:**

1. **Expired Credentials** - Current blocker
   - `argocd-readonly` token is expired
   - No admin credentials available
   - Cannot create Applications

2. **External Dependency** - Reliance on external hub
   - Hub outage affects all clusters
   - Network connectivity required

### Feasibility

**BLOCKED by Expired Credentials** - ArgoCD is online and functional, but cannot authenticate.

**Required Actions:**

1. **Obtain valid credentials** for argocd-manager.ardenone.com
   - Contact ArgoCD administrator
   - Or generate new token if admin access available

2. **Register ardenone-cluster** (if not already registered)
   - Add cluster to external ArgoCD
   - Create ServiceAccount with proper RBAC
   - Configure connection

3. **Create Application** for Moltbook
   - Point to moltbook-org repository
   - Set target cluster to ardenone-cluster
   - Configure sync policy

### Recommendation

**HIGHLY RECOMMENDED** - This is the intended architecture and aligns with hub-and-spoke GitOps pattern.

**Blocker Resolution:**
- **Immediate**: Contact cluster-admin for argocd-manager credentials
- **Alternative**: Locate external ArgoCD cluster and generate new token
- **Bead**: `mo-dbl7` - Fix expired argocd-readonly token

---

## Decision Matrix

| Approach | Feasibility | Security | Effort | Alignment | Recommendation |
|----------|------------|----------|--------|-----------|----------------|
| **1. Helm** | NOT FEASIBLE | Same risks as manifests | Medium | Low | ❌ NOT RECOMMENDED |
| **2. GitHub Actions** | CONDITIONAL | Moderate | Medium | Medium | ⚠️ CONDITIONAL |
| **3. Cluster-Admin Manual** | FEASIBLE | Moderate privilege grant | Low | Low (conflicts with hub) | ❌ NOT RECOMMENDED |
| **4. External ArgoCD** | BLOCKED (credentials) | Best practice | Low | High (intended) | ⭐ RECOMMENDED |

---

## Recommended Path Forward

### Phase 1: Resolve External ArgoCD Access (Recommended)

1. **Contact cluster-admin** for argocd-manager.ardenone.com credentials
2. **Obtain admin or read-write token** for external ArgoCD
3. **Update argocd-readonly secret** in devpod namespace
4. **Create Application** on external ArgoCD for Moltbook
5. **Enable automated sync**

### Phase 2: Alternative Path (If External ArgoCD Unavailable)

1. **Request cluster-admin** to apply `ARGOCD_INSTALL_REQUEST.yml`
2. **Install local ArgoCD** from devpod after RBAC granted
3. **Migrate to external** when credentials become available

### Phase 3: GitHub Actions Path (If ArgoCD Not Required)

1. **Obtain kubeconfig** for ardenone-cluster
2. **Store as GitHub Secret** (use OIDC if possible)
3. **Create workflow** to apply manifests on push
4. **Add drift detection** job

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `k8s/ARGOCD_ARCHITECTURE_RESEARCH_MO_196J_CONSOLIDATED.md` | External ArgoCD architecture research |
| `ARGOCD_BLOCKER_MO_Y5O.md` | Current blocker status |
| `ARGOCD_INSTALLATION_GUIDE.md` | Detailed installation steps |
| `k8s/ARGOCD_INSTALL_REQUEST.yml` | RBAC manifest for cluster-admin |

---

## Related Beads

| Bead | Priority | Description |
|------|----------|-------------|
| **mo-1bci** | 1 | This task - Alternative installation methods research |
| **mo-dbl7** | 1 | Fix expired argocd-readonly token |
| **mo-196j** | 1 | ArgoCD architecture research (external vs local) |
| **mo-y5o** | 0 | ArgoCD installation blocker |

---

## Blockers Identified

### New Bead Required

Based on this research, a new bead should be created to track the external ArgoCD credential resolution:

**Title**: "Fix: External ArgoCD credentials for Moltbook deployment"
**Description**: "argocd-manager.ardenone.com is online but argocd-readonly token is expired. Need valid admin or read-write credentials to create Moltbook Application on external ArgoCD hub."
**Priority**: 1 (High)

---

## Summary

| Approach | Status | Blocker |
|----------|--------|---------|
| Helm | NOT FEASIBLE | Missing tool + permissions |
| GitHub Actions | CONDITIONAL | Requires cluster kubeconfig |
| Cluster-Admin Manual | FEASIBLE | Requires cluster-admin action |
| **External ArgoCD** | **RECOMMENDED** | **Expired credentials** |

**RECOMMENDATION**: Proceed with **External ArgoCD** (Approach 4) - aligns with hub-and-spoke architecture, requires minimal cluster changes, and is the intended GitOps pattern.

**IMMEDIATE ACTION**: Resolve `mo-dbl7` (expired argocd-readonly token) or obtain new credentials for argocd-manager.ardenone.com.

---

**Research Complete**: 2026-02-05
**Next Action**: Create bead for external ArgoCD credentials; commit findings
