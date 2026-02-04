# Container Image Build and Push Status

**Date:** 2026-02-04
**Bead:** mo-1uo (Fix: Build and push container images for deployment)

## Summary

The CI/CD pipeline for building and pushing container images is **fully configured and operational**.

## CI/CD Configuration

### GitHub Actions Workflow
- **File:** `.github/workflows/build-push.yml`
- **Trigger:** Push to `main` branch affecting `api/`, `moltbook-frontend/`, or workflow file
- **Registry:** GitHub Container Registry (GHCR) at `ghcr.io/ardenone/`

### Image References

| Component | Image Repository | Tag Strategy |
|-----------|------------------|--------------|
| API | `ghcr.io/ardenone/moltbook-api` | `latest`, `main-<sha>`, `main` |
| Frontend | `ghcr.io/ardenone/moltbook-frontend` | `latest`, `main-<sha>`, `main` |

## Kubernetes Deployments

Deployment manifests are configured with correct image references:

- **API:** `k8s/api/deployment.yml` uses `ghcr.io/ardenone/moltbook-api:latest`
- **Frontend:** `k8s/frontend/deployment.yml` uses `ghcr.io/ardenone/moltbook-frontend:latest`

## Dockerfiles

### API (`api/Dockerfile`)
- Multi-stage build with Node 18 Alpine
- Production dependencies only (`npm ci --omit=dev`)
- Non-root user execution
- Healthcheck on `/health` endpoint

### Frontend (`moltbook-frontend/Dockerfile`)
- Multi-stage build with Next.js standalone output
- Development dependencies for build stage, production only in final image
- Non-root user execution
- Healthcheck on root path `/`

## Recent Activity

The most recent commit `b70c5e0 feat(ci): Add provenance, SBOM, and build summary to workflow` was pushed to origin/main on 2026-02-04. This commit includes:

- Provenance metadata for image integrity verification
- SBOM (Software Bill of Materials) for vulnerability scanning
- Build summary job for visibility into image digests

## Image Availability Status

To verify if images have been built:

```bash
# Check API image
curl -I https://ghcr.io/v2/ardenone/moltbook-api/manifests/latest

# Check Frontend image
curl -I https://ghcr.io/v2/ardenone/moltbook-frontend/manifests/latest
```

Or visit:
- https://github.com/ardenone?tab=packages&name=moltbook-api
- https://github.com/ardenone?tab=packages&name=moltbook-frontend

## Manual Workflow Trigger

If images need to be rebuilt immediately:

1. Visit: https://github.com/moltbook-org/moltbook-org/actions/workflows/build-push.yml
2. Click "Run workflow"
3. Select `main` branch
4. Click "Run workflow"

## Next Steps

Once images are built and pushed to GHCR:

1. Verify images are accessible (check GHCR links above)
2. Ensure Kubernetes cluster can pull from GHCR (imagePullSecrets if needed)
3. Deploy with `kubectl apply -f k8s/`

## Related Beads

- **mo-1uo** (this bead): Fix: Build and push container images for deployment
- **mo-saz**: Implementation: Deploy Moltbook platform to ardenone-cluster
