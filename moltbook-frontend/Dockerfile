# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY .npmrc ./

# Install all dependencies (including devDependencies for build)
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Ensure .next directory doesn't exist from previous builds
RUN rm -rf .next out

# Build the application with telemetry disabled
# ENV variables to prevent createContext errors during Docker build
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=2048"
ENV NODE_ENV=production

# Clean any previous build artifacts to ensure fresh build
RUN rm -rf .next 2>/dev/null || true

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy standalone output from builder
# When output: 'standalone' is set, Next.js creates a minimal .next/standalone directory
# with only the necessary files and dependencies to run the app
COPY --from=builder /app/.next/standalone ./
# Copy static files
COPY --from=builder /app/.next/static ./.next/static
# Copy public directory
COPY --from=builder /app/public ./public

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

# Start the application using the standalone server
# When output: 'standalone' is used, Next.js generates a server.js file
CMD ["node", "server.js"]
