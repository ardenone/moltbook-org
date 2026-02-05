/** @type {import('next').NextConfig} */
const path = require('path');

const nextConfig = {
  reactStrictMode: true,

  // COMPREHENSIVE FIX FOR "createContext is not a function" IN DOCKER BUILDS
  //
  // Root Cause:
  // Next.js 15 + React 19 attempts to prerender/optimize pages during build time,
  // even with 'use client' directive and 'force-dynamic'. This causes React Context
  // APIs to be executed in a Node.js environment where they're not available.
  //
  // Docker Build Specifics:
  // - Alpine Linux (musl) vs glibc differences
  // - Isolated build environment with no browser APIs
  // - Different memory/CPU constraints
  //
  // Multi-layered Fix Strategy:
  // 1. Use standalone output mode for better bundling
  // 2. Prevent React from being externalized during server-side bundling
  // 3. Disable image optimization (requires server-side processing)
  // 4. Disable webpack build cache (prevents stale artifacts)
  // 5. Force all routes to be dynamically rendered
  // 6. Disable all static optimization features

  // Use standalone output mode for better Docker compatibility
  // This creates a minimal build with only necessary files
  output: 'standalone',

  // Disable source maps in production to reduce build size
  productionBrowserSourceMaps: false,

  // Disable Next.js image optimization (requires server-side processing during build)
  images: {
    unoptimized: true,
  },

  experimental: {
    // Optimize package imports for better tree-shaking
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-avatar',
      '@radix-ui/react-dialog',
      '@radix-ui/react-dropdown-menu',
      '@radix-ui/react-popover',
      '@radix-ui/react-scroll-area',
      '@radix-ui/react-select',
      '@radix-ui/react-switch',
      '@radix-ui/react-tabs',
      '@radix-ui/react-tooltip',
    ],
    // Disable turbo mode - has compatibility issues with React 19 + Radix UI in Docker
    turbo: undefined,
  },

  // Ensure transpilePackages for zustand, Radix UI, and other packages using React context
  transpilePackages: ['zustand', '@radix-ui', 'next-themes', 'sonner', 'framer-motion'],

  // CRITICAL: Webpack configuration to prevent React externalization and Context errors
  webpack: (config, { isServer, dev }) => {
    // ========== RESOLVE CONFIGURATION FIX ==========
    // Ensure React modules resolve correctly by setting up proper resolution paths
    config.resolve = config.resolve || {};

    // Ensure node_modules is in the resolve modules path
    config.resolve.modules = config.resolve.modules || [];
    if (!config.resolve.modules.includes('node_modules')) {
      config.resolve.modules.push('node_modules');
    }

    // Set up React aliases using relative paths to avoid require.resolve issues
    // The key insight: we need to point to the actual package directories
    config.resolve.alias = config.resolve.alias || {};
    config.resolve.alias.react = path.resolve(__dirname, 'node_modules/react');
    config.resolve.alias['react-dom'] = path.resolve(__dirname, 'node_modules/react-dom');
    config.resolve.alias['react/jsx-runtime'] = path.resolve(__dirname, 'node_modules/react/jsx-runtime');

    // ========== SERVER-SIDE BUNDLING FIX ==========
    // When isServer is true, Next.js bundles code for the Node.js server environment
    // The issue: React packages get marked as "external" (not bundled), expecting them
    // to be provided by the Node.js environment. But Node.js doesn't have React Context!
    if (isServer) {
      // Step 1: Remove React from externals so it gets bundled with the server code
      config.externals = config.externals || [];
      const externalsToRemove = [
        'react',
        'react-dom',
        'react/jsx-runtime',
        'react-dom/client',
        'react-dom/server-browser',
        'react-dom/server-edge',
      ];

      // Handle array-format externals (common in Next.js)
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter((external) => {
          if (typeof external === 'string') {
            return !externalsToRemove.includes(external);
          }
          // Keep function and regex externals intact
          return true;
        });
      }
      // Handle function-format externals
      else if (typeof config.externals === 'function') {
        const originalExternals = config.externals;
        config.externals = ({ request, dependencyType, ...args }, callback) => {
          // Don't externalize React packages
          if (externalsToRemove.includes(request)) {
            return callback(null, false);
          }
          return originalExternals({ request, dependencyType, ...args }, callback);
        };
      }

      // Step 2: Add React to the fallbacks for browser-compatible builds
      config.resolve.fallback = config.resolve.fallback || {};
      // Ensure we don't use Node.js-specific modules that don't exist in browser
      config.resolve.fallback.fs = false;
      config.resolve.fallback.net = false;
      config.resolve.fallback.tls = false;
    }

    // ========== MODULE CONCATENATION FIX ==========
    // Disable module concatenation for React packages to prevent build-time issues
    // This is critical for Next.js 15 + React 19
    config.optimization = config.optimization || {};
    config.optimization.concatenateModules = false;

    // ========== BUILD CACHE FIX ==========
    // Disable webpack cache in production to prevent stale build artifacts
    // This is critical in Docker where cached .next directory might persist
    if (!dev) {
      config.cache = false;
    }

    return config;
  },
};

module.exports = nextConfig;
