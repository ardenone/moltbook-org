# moltbook-org Research

Private deployment study for moltbook and OpenClaw agents.

## Quick Links

- **[Docker Build Documentation](DOCKER_BUILD.md)** - How to build Docker images (important for devpod users)
- **[Build Status Script](scripts/check-build-status.sh)** - Check GitHub Actions build status

## Initial Setup (One-Time)

### Namespace Creation (Requires Cluster Admin)

The `moltbook` namespace must be created before deploying the application. There are two options:

**Option 1: Run Helper Script (Recommended)**

```bash
# Run this as cluster admin - creates RBAC + namespace in one step
./scripts/create-moltbook-namespace.sh
```

**Option 2: Manual Setup**

Create RBAC to allow devpod namespace creation (recommended for development):

```bash
# Run this as cluster admin
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
```

Or create just the namespace:

```bash
# Run this as cluster admin
kubectl apply -f k8s/NAMESPACE_REQUEST.yml
```

### Verify Namespace Exists

```bash
kubectl get namespace moltbook
```

## Deployment

After the namespace exists, deploy all resources:

```bash
kubectl apply -k k8s/
```

## Current Status

**BLOCKER**: The `moltbook` namespace does not exist and requires cluster admin intervention.

- **Bead mo-2bxj**: BLOCKER: Cluster Admin - Apply RBAC for Moltbook namespace creation (P0)
- See `DEPLOYMENT_GUIDE.md` for detailed instructions
- See `DEPLOYMENT_BLOCKER.md` for blocker status

Once the namespace is created, deployment can proceed automatically via ArgoCD or manually via kubectl.

## Important Note for Developers

**Do not build Docker images inside the devpod** - it will fail with overlay filesystem errors due to container-in-container limitations.

Instead, use the automated GitHub Actions workflow:
```bash
# Push your changes - images build automatically
git add .
git commit -m "feat: Your feature"
git push origin main

# Or trigger a manual build
gh workflow run build-push.yml

# Check build status
./scripts/check-build-status.sh
```

See [DOCKER_BUILD.md](DOCKER_BUILD.md) for full details.
