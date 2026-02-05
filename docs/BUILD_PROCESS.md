# Moltbook Build Process Guide

**Updated**: 2026-02-05

---

## Overview

This guide explains how to build Moltbook container images for deployment to Kubernetes.

---

## Quick Reference

| Use Case | Solution | Command |
|----------|----------|---------|
| CI/CD Production | GitHub Actions | `git push origin main` |
| Devpod Development | Kaniko | `./scripts/kaniko-build.sh --all` |
| Local Testing | Host Machine | `docker build -t ... api/` |

---

## Solution 1: GitHub Actions (Recommended)

Builds run on GitHub's Ubuntu runners automatically when you push to main.

### Usage

```bash
# Automatic - builds on push to main
git add .
git commit -m "feat: My changes"
git push origin main

# Manual trigger
gh workflow run build-push.yml
gh run watch
```

### Output

- Images pushed to `ghcr.io/ardenone/moltbook-api:latest`
- Images pushed to `ghcr.io/ardenone/moltbook-frontend:latest`
- Kustomization updated with new image tags

---

## Solution 2: Kaniko (In-Cluster)

Build images directly from devpod without Docker daemon.

### Setup (One-Time)

```bash
# 1. Create GHCR credentials secret
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=ardenone \
  --docker-password=<GITHUB_TOKEN> \
  -n moltbook

# 2. Deploy Kaniko runner
kubectl apply -f k8s/kaniko/
```

### Build Commands

```bash
# Build both images
./scripts/kaniko-build.sh --all

# Build API only
./scripts/kaniko-build.sh --api-only

# Build with custom tag
./scripts/kaniko-build.sh --tag v1.0.0 --all

# Deploy and build in one command
./scripts/kaniko-build.sh --deploy --all
```

---

## Solution 3: Host Machine

Build on your physical workstation outside devpod.

### Commands

```bash
# Build API
docker build -t ghcr.io/ardenone/moltbook-api:latest api/

# Build Frontend
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/

# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin

# Push
docker push ghcr.io/ardenone/moltbook-api:latest
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## File Structure

```
moltbook-org/
├── .github/workflows/build-push.yml    # GitHub Actions workflow
├── k8s/kaniko/                          # Kaniko manifests
│   ├── build-runner-deployment.yml
│   ├── build-scripts-configmap.yml
│   └── README.md
├── scripts/
│   ├── kaniko-build.sh                  # Kaniko helper
│   ├── build-images.sh                  # Docker script (host)
│   └── build-images-safe.sh             # Safe wrapper
├── api/Dockerfile
└── moltbook-frontend/Dockerfile
```

---

## See Also

- [DOCKER_BUILD_SOLUTIONS.md](../DOCKER_BUILD_SOLUTIONS.md) - Complete solution comparison
- [k8s/kaniko/README.md](../k8s/kaniko/README.md) - Kaniko detailed guide
