# Prepared Dockerfiles - Ready to Push

## Status
**Ready to Push**: Yes (awaiting GitHub permissions)
**Date Prepared**: 2026-02-04
**Locations**: `/tmp/moltbook-api-test/`, `/tmp/moltbook-frontend-test/`

## Overview
Two Dockerfiles have been prepared and committed locally. Once `jedarden` receives push permissions to the moltbook organization repositories, these commits can be pushed to trigger GitHub Actions for Docker image builds.

---

## API Repository

### Location
```
/tmp/moltbook-api-test/
```

### Commit Information
- **Branch**: `main`
- **Commit**: `b4dbc8d`
- **Message**: `feat: Add Dockerfile for containerized deployment`
- **Status**: 1 commit ahead of origin/main

### Dockerfile Details
```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy source code
COPY src/ ./src/

# Production stage
FROM node:18-alpine

WORKDIR /app

# Copy node_modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy source code
COPY --from=builder /app/src ./src
COPY package*.json ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "src/index.js"]
```

### Features
- Multi-stage build for smaller image size
- Node.js 18 Alpine base image
- Production dependencies only (`npm ci --omit=dev`)
- Non-root user execution (security best practice)
- Health check on `/health` endpoint
- Port 3000 exposed

### Push Command
```bash
cd /tmp/moltbook-api-test
git push origin main
```

---

## Frontend Repository

### Location
```
/tmp/moltbook-frontend-test/
```

### Commit Information
- **Branch**: `main`
- **Commit**: `ceeda92`
- **Message**: `feat: Add Dockerfile for containerized deployment`
- **Status**: 1 commit ahead of origin/main

### Dockerfile Details
```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy built application from builder (standalone output includes all needed files)
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/static ./.next/static

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application (standalone output creates server.js)
CMD ["node", "server.js"]
```

### Features
- Multi-stage build for Next.js optimization
- Uses `next.config.js` `output: 'standalone'` for minimal runtime
- Build stage installs all dependencies including devDependencies
- Production stage only includes built artifacts
- Non-root user execution
- Health check on `/` endpoint
- Port 3000 exposed

### Push Command
```bash
cd /tmp/moltbook-frontend-test
git push origin main
```

---

## Expected GitHub Actions Behavior

After pushing these commits, the following will occur:

### API Repository
1. GitHub Actions workflow triggers on push to `main`
2. Docker image built: `ghcr.io/moltbook/api:latest`
3. Image tagged with commit SHA: `ghcr.io/moltbook/api:b4dbc8d`

### Frontend Repository
1. GitHub Actions workflow triggers on push to `main`
2. Docker image built: `ghcr.io/moltbook/moltbook-frontend:latest`
3. Image tagged with commit SHA: `ghcr.io/moltbook/moltbook-frontend:ceeda92`

---

## Prerequisites

Before pushing, ensure:

1. **Permissions**: `jedarden` has push access to both repositories
   - Verify: `gh api repos/moltbook/api --jq .permissions`
   - Verify: `gh api repos/moltbook/moltbook-frontend --jq .permissions`

2. **GitHub Actions Workflows**: Ensure workflows exist in both repos
   - Check: `.github/workflows/docker-build.yml` or similar

3. **Container Registry**: Ensure GHCR is configured
   - Check repository settings > Actions > General > Workflow permissions

---

## Related Documentation

- **Permissions Blocker**: See `GITHUB_PERMISSIONS_BLOCKER.md`
- **Original Analysis**: See `GITHUB_PERMISSIONS_REQUIRED.md`
- **Bead**: mo-2fi

---

**Last Updated**: 2026-02-04
