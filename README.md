# moltbook-org Research

Private deployment study for moltbook and OpenClaw agents.

## Quick Links

- **[Docker Build Documentation](DOCKER_BUILD.md)** - How to build Docker images (important for devpod users)
- **[Build Status Script](scripts/check-build-status.sh)** - Check GitHub Actions build status

## Initial Setup (One-Time)

### Namespace Creation

The `moltbook` namespace must be created before deploying the application. There are two options:

**Option 1: Cluster Admin Creates RBAC (Recommended for Devpod Users)**

A cluster admin should apply the RBAC manifest to grant the devpod ServiceAccount namespace creation permissions:

```bash
# Run this as cluster admin (outside devpod or with cluster-admin privileges)
kubectl apply -f k8s/namespace/devpod-namespace-creator-rbac.yml
```

After the RBAC is applied, the devpod can create namespaces:

```bash
# Now this will work from the devpod
kubectl apply -f k8s/namespace/moltbook-namespace.yml
```

**Option 2: Cluster Admin Creates Namespace Directly**

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
