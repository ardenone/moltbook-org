# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies for build)
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the application with telemetry disabled
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Ensure public directory exists (even if empty) for the COPY instruction
RUN mkdir -p /app/public && touch /app/public/.gitkeep

# Production stage
FROM node:20-alpine

WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy built application from builder (standalone output includes all needed files)
# Next.js standalone output is at .next/standalone/
COPY --from=builder /app/.next/standalone/ ./
# Copy static assets from build
COPY --from=builder /app/.next/static ./.next/static
# Copy public directory (ensured to exist in build stage)
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

# Start the application (standalone output creates server.js)
CMD ["node", "server.js"]
