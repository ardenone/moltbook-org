# Frontend Build Instructions

## Problem: Devpod Storage Issues

Docker builds in the devpod environment fail due to overlay filesystem corruption. The build cache gets stuck with 53+ active builds and builds hang indefinitely.

## Solution: Use External CI (GitHub Actions)

The frontend container image is built via GitHub Actions CI and pushed to `ghcr.io/ardenone/moltbook-frontend:latest`.

### Triggering a Build

1. **Automatic on push**: Push to `main` branch triggers a build
2. **Manual trigger**: Use GitHub Actions UI to run "Build Container Images" workflow

### Build Workflow

The `.github/workflows/build-images.yml` workflow:
- Builds both `moltbook-api` and `moltbook-frontend` images
- Pushes to `ghcr.io/ardenone/moltbook-frontend:latest`
- Updates `k8s/kustomization.yml` with the new image tag

### Local Development (No Docker Build Required)

For local development, use the native Next.js dev server:

```bash
cd moltbook-frontend
pnpm install
pnpm dev
```

### Testing Production Build Locally

To test the production build without Docker:

```bash
cd moltbook-frontend
pnpm build
pnpm start
```

This builds the frontend using Next.js 16 + Turbopack and starts the production server on port 3000.

### Node.js Requirements

- Next.js 16.1.6 requires **Node.js >=20.9.0**
- Devpod has Node.js v24.12.0 installed (compatible)

### Dockerfile Notes

The `Dockerfile` is correctly configured for Node.js 20+:
- Uses `node:20-alpine` base image
- Installs pnpm for dependency management
- Builds with Turbopack for Next.js 16
- Health check on port 3000

### Image Reference

After the GitHub Actions build completes:
```yaml
image: ghcr.io/ardenone/moltbook-frontend:latest
```

### Kaniko Build (Alternative)

For in-cluster builds, use the Kaniko build runner:
```bash
kubectl apply -f k8s/kaniko/
```

This is less reliable than GitHub Actions due to the same overlay filesystem issues.
