# Moltbook Kubernetes Manifests

This directory contains all Kubernetes manifests for deploying the Moltbook platform to ardenone-cluster using GitOps with ArgoCD.

## Quick Start

See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment instructions.

```bash
# Generate SealedSecrets
./scripts/generate-sealed-secrets.sh

# Deploy everything
./scripts/deploy.sh
```

## Directory Structure

```
k8s/
├── namespace/           # Namespace definition
├── database/           # PostgreSQL (CNPG) and Redis
├── api/                # Backend API deployment
├── frontend/           # Frontend (Next.js) deployment
├── ingress/            # Traefik IngressRoute configuration
├── secrets/            # SealedSecret templates
├── argocd/             # ArgoCD Application manifest
└── README.md           # This file
```

## Access URLs

- Frontend: https://moltbook.ardenone.com
- API: https://api-moltbook.ardenone.com
- Health Check: https://api-moltbook.ardenone.com/api/v1/health
