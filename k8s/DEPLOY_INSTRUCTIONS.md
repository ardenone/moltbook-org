# Moltbook Deployment Instructions - ardenone-cluster

**Last Updated:** 2026-02-04

**Prerequisites:**
- Access to ardenone-cluster
- kubectl configured with cluster-admin access (for initial setup)
- CNPG (CloudNativePG) operator installed
- SealedSecrets controller installed
- Traefik ingress controller installed

---

## Part 1: Initial Setup (Cluster Admin Only)

The devpod ServiceAccount needs permission to create namespaces. This requires cluster-admin access.

### Step 1: Apply ClusterRoleBinding for Namespace Creation

```bash
# Apply the ClusterRole and ClusterRoleBinding
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/devpod-namespace-creator-rbac.yml

# Verify the ClusterRoleBinding was created
kubectl get clusterrolebinding devpod-namespace-creator
```

**What this does:**
- Creates a `ClusterRole` named `namespace-creator`
- Grants the `default` ServiceAccount in `devpod` namespace permission to create namespaces
- Allows the devpod to set up RBAC in new namespaces

---

## Part 2: Deploy Moltbook (Devpod ServiceAccount)

Once the ClusterRoleBinding is applied, the devpod ServiceAccount can complete the deployment.

### Step 2: Create Namespace and Apply RBAC

```bash
# From the devpod, create the namespace
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-namespace.yml

# Apply RBAC for the namespace
kubectl apply -f /home/coder/Research/moltbook-org/k8s/namespace/moltbook-rbac.yml

# Verify namespace exists
kubectl get namespace moltbook
```

### Step 3: Apply SealedSecrets

```bash
# Apply all SealedSecrets (encrypted secrets)
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-postgres-superuser-sealedsecret.yml
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-db-credentials-sealedsecret.yml
kubectl apply -f /home/coder/Research/moltbook-org/k8s/secrets/moltbook-api-sealedsecret.yml

# Verify SealedSecrets were created and decrypted
kubectl get secrets -n moltbook
```

### Step 4: Deploy All Resources with Kustomize

```bash
# Navigate to the moltbook-org directory
cd /home/coder/Research/moltbook-org

# Apply all resources using kustomize
kubectl apply -k k8s/

# Verify all resources are created
kubectl get all -n moltbook
```

### Step 5: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n moltbook

# Check services
kubectl get svc -n moltbook

# Check IngressRoutes
kubectl get ingressroutes -n moltbook

# Check CNPG cluster
kubectl get cluster -n moltbook

# Check database initialization
kubectl logs -n moltbook deployment/moltbook-db-init --tail=50
```

---

## Part 3: Verify Application Access

### Step 6: Test Application Endpoints

```bash
# Test API health endpoint
curl https://api-moltbook.ardenone.com/health

# Test frontend (should return HTML)
curl https://moltbook.ardenone.com

# Check DNS resolution
nslookup moltbook.ardenone.com
nslookup api-moltbook.ardenone.com
```

### Expected Results

- **Frontend:** https://moltbook.ardenone.com - Next.js application loads
- **API:** https://api-moltbook.ardenone.com/health - Returns `{"status":"ok"}`
- **API Docs:** https://api-moltbook.ardenone.com - API documentation (if available)

---

## Part 4: Troubleshooting

### Pods Not Starting

```bash
# Describe pod for events
kubectl describe pod -n moltbook <pod-name>

# View pod logs
kubectl logs -n moltbook <pod-name>

# View init container logs
kubectl logs -n moltbook <pod-name> -c <init-container-name>
```

### Database Issues

```bash
# Check CNPG cluster status
kubectl get cluster -n moltbook
kubectl describe cluster moltbook-postgres -n moltbook

# Check database connection
kubectl exec -it -n moltbook moltbook-api-xxxxx -- sh
# Then: psql $DATABASE_URL
```

### SealedSecrets Not Decrypting

```bash
# Check SealedSecret controller is running
kubectl get pods -n sealed-secrets

# Check SealedSecret status
kubectl get sealedsecrets -n moltbook
kubectl describe sealedsecret <name> -n moltbook

# Check if Secret was created
kubectl get secrets -n moltbook
```

### Ingress/Routing Issues

```bash
# Check Traefik middlewares
kubectl get middlewares -n moltbook

# Check IngressRoute status
kubectl get ingressroutes -n moltbook
kubectl describe ingressroute <name> -n moltbook

# Check Traefik logs
kubectl logs -n traefik deployment/traefik
```

---

## Part 5: GitOps Deployment (ArgoCD)

For automated deployment with ArgoCD:

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f /home/coder/Research/moltbook-org/k8s/argocd-application.yml

# Verify application was created
kubectl get applications -n argocd

# Sync the application (if not auto-syncing)
argocd app sync moltbook

# Check application status
argocd app get moltbook
```

---

## Part 6: Maintenance

### Rotating Secrets

1. Update the template files in `k8s/secrets/`:
   - `postgres-superuser-secret-template.yml`
   - `moltbook-db-credentials-template.yml`
   - `moltbook-api-secrets-template.yml`

2. Generate new SealedSecrets:
   ```bash
   kubeseal --format yaml < <template-file> > <sealedsecret-file>
   ```

3. Apply the new SealedSecrets:
   ```bash
   kubectl apply -f <sealedsecret-file>
   ```

### Scaling Deployments

```bash
# Scale API
kubectl scale deployment/moltbook-api -n moltbook --replicas=3

# Scale Frontend
kubectl scale deployment/moltbook-frontend -n moltbook --replicas=3
```

### Database Backups

```bash
# Create a manual backup
kubectl create -n moltbook -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: moltbook-backup-manual-$(date +%Y%m%d)
spec:
  cluster: moltbook-postgres
EOF

# List backups
kubectl get backups -n moltbook
```

---

## Deployment Architecture Summary

```
moltbook namespace:
  ├─ moltbook-postgres (CNPG Cluster, 1 instance)
  │   ├─ moltbook-postgres-rw Service (ReadWrite)
  │   ├─ moltbook-postgres-ro Service (ReadOnly)
  │   └─ moltbook-postgres Service
  │
  ├─ moltbook-redis (Deployment, 1 replica)
  │   └─ moltbook-redis Service
  │
  ├─ moltbook-db-init (Deployment, 1 replica)
  │   └─ Initializes database schema
  │
  ├─ moltbook-api (Deployment, 2 replicas)
  │   └─ moltbook-api Service
  │       └─ IngressRoute: api-moltbook.ardenone.com
  │
  └─ moltbook-frontend (Deployment, 2 replicas)
      └─ moltbook-frontend Service
          └─ IngressRoute: moltbook.ardenone.com
```

---

## Contact and Support

For issues or questions:
- Check bead **mo-saz** for implementation details
- Check bead **mo-1zt** for RBAC setup status
- Review `/home/coder/Research/moltbook-org/k8s/DEPLOYMENT_STATUS.md` for current status
- Review `/home/coder/Research/moltbook-org/k8s/VALIDATION_REPORT.md` for validation details
