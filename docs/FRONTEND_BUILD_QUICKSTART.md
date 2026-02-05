# Frontend Build Quickstart Guide

This guide answers the most common questions about building the Moltbook frontend.

---

## ❓ Common Questions

### "I can't build the frontend in devpod!"

**Correct!** You cannot build Docker images in devpod due to overlay filesystem limitations.

**Solution**: Use GitHub Actions (automatic on push) or build on your host machine.

**See**: `docs/MO_3BOL_RESOLUTION.md` for full explanation.

---

## 🚀 Quick Start

### Option 1: Automatic Build (Recommended)

Just push your code:

```bash
git add .
git commit -m "feat: My changes"
git push origin main
```

GitHub Actions will automatically build and push both API and Frontend images.

**Check status**:
```bash
gh run list --limit 5
gh run watch
```

### Option 2: Manual Trigger

```bash
# Trigger GitHub Actions workflow
./scripts/build-images-devpod.sh

# With live monitoring
./scripts/build-images-devpod.sh --watch
```

### Option 3: Local Development (No Docker)

For testing without building containers:

```bash
cd moltbook-frontend

# Install dependencies
npm install --legacy-peer-deps

# Run dev server
npm run dev

# Run tests
npm test

# Type check
npm run type-check

# Lint
npm run lint
```

---

## 🐳 Docker Builds

### In Devpod: ❌ NOT POSSIBLE

```bash
# This WILL FAIL in devpod:
docker build -t test-build .
# ERROR: mount source: "overlay"... invalid argument
```

### On Host Machine: ✅ WORKS

```bash
# On your local machine (MacOS/Linux)
docker build -t ghcr.io/ardenone/moltbook-frontend:latest moltbook-frontend/
echo $GITHUB_TOKEN | docker login ghcr.io -u github --password-stdin
docker push ghcr.io/ardenone/moltbook-frontend:latest
```

---

## 📦 Available Images

Images are automatically pushed to GitHub Container Registry:

- **Frontend**: `ghcr.io/ardenone/moltbook-frontend:latest`
- **API**: `ghcr.io/ardenone/moltbook-api:latest`

**Pull locally**:
```bash
docker pull ghcr.io/ardenone/moltbook-frontend:latest
docker pull ghcr.io/ardenone/moltbook-api:latest
```

---

## 🚢 Deployment

After images are built:

### ArgoCD (Auto-Sync)

If auto-sync is enabled, deployments update automatically.

### Manual Rollout

```bash
# Restart frontend
kubectl rollout restart deployment/moltbook-frontend -n moltbook

# Restart API
kubectl rollout restart deployment/moltbook-api -n moltbook

# Check status
kubectl rollout status deployment/moltbook-frontend -n moltbook
```

### ArgoCD Manual Sync

```bash
argocd app sync moltbook
```

---

## 🔍 Troubleshooting

### "npm install fails with ENOTEMPTY"

This is likely **NOT** the real issue. The actual problem is Docker overlay filesystem.

**Read**: `docs/MO_3BOL_RESOLUTION.md` for full investigation.

### "Docker build fails in devpod"

This is expected! Use GitHub Actions instead.

**See**: `DOCKER_BUILD_WORKAROUND.md`

### "Workflow failed"

Check recent runs:

```bash
gh run list --limit 10
gh run view <run-id> --log
```

Most failures are git push race conditions (already fixed with retry logic).

### "Images not updating"

Check if workflow ran:

```bash
gh run list --workflow=build-push.yml
```

Trigger manually if needed:

```bash
./scripts/build-images-devpod.sh --watch
```

---

## 📚 Full Documentation

- **Frontend Build Issue**: `docs/MO_3BOL_RESOLUTION.md`
- **Docker Build Workaround**: `DOCKER_BUILD_WORKAROUND.md`
- **Docker Build Solution**: `DOCKER_BUILD_SOLUTION.md`
- **Container Builds**: `docs/container-builds.md`

---

## 🎯 Best Practices

1. **Push to main** → Automatic build via GitHub Actions
2. **Use `--watch` flag** → Monitor build progress in real-time
3. **Don't build in devpod** → It will fail with overlay error
4. **Test locally** → Use `npm run dev` for development
5. **Check workflow status** → Use `gh run list` to see builds

---

## 🔄 Workflow Status

Check if GitHub Actions is working:

```bash
# List recent runs
gh run list --workflow=build-push.yml --limit 10

# Watch latest run
gh run watch

# View specific run
gh run view <run-id>
```

**Expected**: Most recent runs should show `completed success`.

---

**Last Updated**: 2026-02-05
**Related Bead**: mo-3bol
