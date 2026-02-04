# moltbook-org Research

Private deployment study for moltbook and OpenClaw agents.

## Quick Links

- **[Cluster Admin Setup Guide](k8s/CLUSTER_ADMIN_README.md)** - **START HERE if namespace doesn't exist**
- **[Docker Build Documentation](DOCKER_BUILD.md)** - How to build Docker images (important for devpod users)
- **[Build Status Script](scripts/check-build-status.sh)** - Check GitHub Actions build status

## Initial Setup (One-Time)

### Namespace Creation (Requires Cluster Admin)

**ACTION REQUIRED**: The `moltbook` namespace must be created by a cluster administrator.

See **[k8s/CLUSTER_ADMIN_README.md](k8s/CLUSTER_ADMIN_README.md)** for quick instructions.

Quick options:

```bash
# Option 1: Create namespace only (30 seconds)
kubectl create namespace moltbook

# Option 2: Grant RBAC + create namespace (recommended for development)
kubectl apply -f k8s/NAMESPACE_SETUP_REQUEST.yml
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

- **Bead mo-3rs**: Fix: Grant devpod namespace creation permissions or create moltbook namespace (P0)
- See `k8s/CLUSTER_ADMIN_README.md` for cluster admin instructions
- See `k8s/DEPLOYMENT_BLOCKER_MO-CX8.md` for detailed blocker analysis

Once the namespace is created, deployment can proceed automatically.

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
