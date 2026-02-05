/** @type {import('next').NextConfig} */
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
  // 1. Disable all static optimization features
  // 2. Prevent React from being externalized during server-side bundling
  // 3. Disable image optimization (requires server-side processing)
  // 4. Disable webpack build cache (prevents stale artifacts)
  // 5. Force all routes to be dynamically rendered
  // 6. Use client-side only rendering for Context-based providers (dynamic imports with ssr: false)

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

  // TEMPORARILY DISABLED: standalone output mode
  // This was causing build errors with routes-manifest.json not being found
  // The Docker deployment should still work without standalone mode
  // output: 'standalone',

  // Fix for multiple lockfiles warning
  outputFileTracingRoot: process.cwd(),

  // CRITICAL: Webpack configuration to prevent React externalization and Context errors
  webpack: (config, { isServer, dev }) => {
    // ========== REACT MODULE RESOLUTION FIX (BOTH CLIENT AND SERVER) ==========
    // Ensure React modules resolve correctly for both client and server bundles
    config.resolve = config.resolve || {};

    // Ensure node_modules is in the resolve modules path
    config.resolve.modules = config.resolve.modules || [];
    if (!config.resolve.modules.includes('node_modules')) {
      config.resolve.modules.push('node_modules');
    }

    // ========== SERVER-SIDE BUNDLING FIX ==========
    // When isServer is true, Next.js bundles code for the Node.js server environment
    // The issue: React packages get marked as "external" (not bundled), expecting them
    // to be provided by the Node.js environment. But Node.js doesn't have React Context!
    if (isServer) {
      // CRITICAL FIX: Next.js 15's server-side externalization configuration
      // Next.js marks React as external to avoid bundling it server-side, but this
      // breaks when React Context APIs are called during the build phase.
      // Solution: Filter out React-related externals so they get bundled.

      const originalExternals = config.externals;

      // Packages that should be bundled (not externalized) on the server side
      const packagesToBundle = [
        'react',
        'react-dom',
        'react/jsx-runtime',
        'react-dom/client',
        'react-dom/server-browser',
        'react-dom/server-edge',
        'next-themes',
        'sonner',
        'zustand',
      ];

      // Wrap externals to filter React packages
      if (typeof originalExternals === 'function') {
        config.externals = async ({ request, dependencyType, ...args }) => {
          // Don't externalize React packages - let them be bundled
          if (packagesToBundle.some(pkg => request === pkg || request?.startsWith(pkg + '/'))) {
            return false; // false = don't externalize
          }
          return originalExternals({ request, dependencyType, ...args });
        };
      } else if (Array.isArray(originalExternals)) {
        config.externals = originalExternals.filter((external) => {
          if (typeof external === 'string') {
            return !packagesToBundle.some(pkg => external === pkg || external.startsWith(pkg + '/'));
          }
          return true;
        });
      }

      // Disable module concatenation to prevent React build issues
      config.optimization = config.optimization || {};
      config.optimization.concatenateModules = false;
    }

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
