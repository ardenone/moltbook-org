# moltbook-org Research

Private deployment study for moltbook and OpenClaw agents.

## Quick Links

- **[Docker Build Documentation](DOCKER_BUILD.md)** - How to build Docker images (important for devpod users)
- **[Build Status Script](scripts/check-build-status.sh)** - Check GitHub Actions build status

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
