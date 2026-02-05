# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
# NOTE: This project uses pnpm, not npm - so we copy pnpm-lock.yaml
COPY package.json pnpm-lock.yaml ./
COPY .npmrc ./

# Install pnpm globally
RUN npm install -g pnpm

# CRITICAL: Use pnpm install for cleaner, more reliable installs
# This project uses pnpm (not npm) - pnpm-lock.yaml is the lock file
# pnpm handles Docker overlay filesystem issues better than npm
RUN pnpm install --frozen-lockfile || \
    (rm -rf node_modules && pnpm install)

# Copy source code
COPY . .

# Ensure .next directory doesn't exist from previous builds
RUN rm -rf .next out

# Build the application with telemetry disabled
# ENV variables to prevent createContext errors during Docker build
# and handle node: prefixed imports from Next.js testmode
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV NODE_ENV=production

# Clean any previous build artifacts to ensure fresh build
RUN rm -rf .next 2>/dev/null || true

# Build the application
# The build script uses --turbopack flag for Next.js 16
RUN pnpm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy package files
# NOTE: This project uses pnpm, not npm - so we copy pnpm-lock.yaml
COPY package.json pnpm-lock.yaml ./
COPY .npmrc ./

# Install pnpm globally
RUN npm install -g pnpm

# Install all dependencies (not just production)
# CRITICAL: Next.js requires all dependencies at runtime when using npm start
# The --prod flag would exclude @swc/helpers and other required packages
# Use pnpm install with frozen-lockfile for reproducible installs
RUN pnpm install --frozen-lockfile || \
    (rm -rf node_modules && pnpm install)

# Copy built application from builder
COPY --from=builder /app/.next ./.next
# Copy public directory
COPY --from=builder /app/public ./public
# Copy source files (needed for non-standalone mode)
COPY --from=builder /app/src ./src
# Copy config files
COPY --from=builder /app/next.config.js ./next.config.js
COPY --from=builder /app/postcss.config.js ./postcss.config.js
COPY --from=builder /app/tailwind.config.ts ./tailwind.config.ts

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

# Start the application using Next.js built-in server
CMD ["pnpm", "start"]
