# Kaniko Build Runner for Kubernetes

## Overview

This directory contains manifests for running **Kaniko** as a long-running deployment in Kubernetes. Kaniko is a daemonless container image builder that works without Docker daemon or privileged mode, making it ideal for building images in containerized environments like devpods.

## Why Kaniko?

The devpod environment runs inside Kubernetes with overlayfs storage. When Docker tries to build images, it creates **nested overlayfs mounts**, which the Linux kernel doesn't support. This causes errors like:

```
ERROR: mount source: "overlay", target: "...", fstype: overlay, flags: 0, data: "...", err: invalid argument
```

Kaniko solves this by:
- Building images without Docker daemon (daemonless)
- Not requiring nested overlayfs
- Working in standard Kubernetes pods
- Supporting GHCR authentication

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              kaniko-build-runner Deployment              │
│  ┌────────────────────────────────────────────────────┐ │
│  │              kaniko executor container              │ │
│  │  ┌──────────────────────────────────────────────┐  │ │
│  │  │  Build Scripts (ConfigMap)                    │  │ │
│  │  │  - build-all.sh                               │  │ │
│  │  │  - build-api.sh                               │  │ │
│  │  │  - build-frontend.sh                          │  │ │
│  │  └──────────────────────────────────────────────┘  │ │
│  │                                                      │ │
│  │  Volumes:                                           │ │
│  │  - /workspace (emptyDir) - Build context           │ │
│  │  - /cache (emptyDir) - Layer cache                 │ │
│  │  - /scripts (ConfigMap) - Build scripts            │ │
│  │  - /kaniko/.docker (Secret) - GHCR credentials     │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │    GHCR     │
                   │ ghcr.io/    │
                   └─────────────┘
```

## Quick Start

### 1. Create GHCR Credentials

```bash
# Create a Personal Access Token at https://github.com/settings/tokens
# Required scopes: write:packages, read:packages

kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  -n moltbook
```

### 2. Deploy Kaniko Runner

```bash
# Apply all manifests in this directory
kubectl apply -f k8s/kaniko/

# Verify deployment
kubectl get deployment -n moltbook kaniko-build-runner
kubectl logs -n moltbook deployment/kaniko-build-runner
```

### 3. Trigger a Build

```bash
# Build both API and Frontend images
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-all.sh

# Build only API
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-api.sh

# Build only Frontend
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- /scripts/build-frontend.sh

# Use custom tag
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- env IMAGE_TAG=v1.0.0 /scripts/build-all.sh
```

## Manifests

| File | Description |
|------|-------------|
| `build-runner-deployment.yml` | Kaniko deployment with build scripts |
| `build-scripts-configmap.yml` | Shell scripts for building images |
| `ghcr-credentials-template.yml` | Template for GHCR credentials secret |

## Build Scripts

The Kaniko runner includes pre-configured build scripts:

- **`/scripts/build-all.sh`** - Build both API and Frontend
- **`/scripts/build-api.sh`** - Build API only
- **`/scripts/build-frontend.sh`** - Build Frontend only

### Kaniko Flags Used

| Flag | Purpose |
|------|---------|
| `--context` | Path to build context |
| `--dockerfile` | Path to Dockerfile |
| `--destination` | Image registry destination (supports multiple tags) |
| `--cache=true` | Enable layer caching for faster builds |
| `--cache-dir=/cache` | Directory for cache storage |
| `--snapshotMode=redo` | Force redo of snapshots (cleaner builds) |
| `--use-new-run` | Use new RUN command implementation |

## Interactive Debugging

For debugging build issues:

```bash
# Enter the pod
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- sh

# Test manual kaniko command
executor \
  --context=/workspace/api \
  --dockerfile=/workspace/api/Dockerfile \
  --destination=ghcr.io/ardenone/moltbook-api:test \
  --no-push
```

## Comparison: Build Options

| Option | Pros | Cons | Best For |
|--------|------|------|----------|
| **GitHub Actions** | Native Ubuntu runners, no Docker needed, CI/CD integration | External dependency, network latency | Production CI/CD |
| **Kaniko (Cluster)** | No nested overlay, runs in-cluster, fast local builds | Requires cluster resources | Devpod development |
| **Host Machine** | Full Docker control, fastest builds | Requires leaving devpod | Local testing |

## Troubleshooting

### Build Failures

1. **Authentication Error**
   ```bash
   # Verify credentials
   kubectl get secret ghcr-credentials -n moltbook -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
   ```

2. **Context Not Found**
   - Ensure source code is accessible in the pod
   - May need to mount project directory as volume

3. **Out of Memory**
   ```bash
   # Increase limits in build-runner-deployment.yml
   resources.limits.memory: "2Gi"
   ```

### Cleanup

```bash
# Remove Kaniko runner
kubectl delete -f k8s/kaniko/

# Clear build cache
kubectl exec -it deployment/kaniko-build-runner -n moltbook -- rm -rf /cache/*
```

## References

- [Kaniko GitHub](https://github.com/GoogleContainerTools/kaniko)
- [Kaniko in Kubernetes](https://github.com/GoogleContainerTools/kaniko#running-kaniko-in-a-kubernetes-cluster)
- [GHCR Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## Status

| Bead | Title | Status |
|------|-------|--------|
| mo-3t8p | Fix: Docker overlay filesystem prevents image builds in devpod | 🔄 In Progress |
