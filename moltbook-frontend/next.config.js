/** @type {import('next').NextConfig} */
const nextConfig = {
  // CRITICAL: Disable reactStrictMode for React 19 + Next.js 16
  // Strict mode double-invocation during build can cause createContext errors
  reactStrictMode: false,

  productionBrowserSourceMaps: false,

  // Disable static image optimization for container deployment
  images: {
    unoptimized: true,
  },

  // CRITICAL: Disable file tracing to prevent build errors with Next.js 16
  // Next.js 16 + React 19 may execute client-side code during build phase
  // causing createContext errors. This configuration ensures proper isolation.
  outputFileTracingExcludes: {
    '*': [
      'node_modules/@swc/core-linux-x64-gnu',
      'node_modules/@swc/core-linux-x64-musl',
      'node_modules/@swc/core-darwin-x64',
      'node_modules/@swc/core-darwin-arm64',
      'node_modules/@swc/core-win32-x64-msvc',
      'node_modules/@swc/wasi-*',
      'node_modules/esbuild/linux',
      'node_modules/esbuild/darwin',
      'node_modules/esbuild/win32',
      '.git',
      '.next/cache',
      '.git/**',
      '**/.git/**',
      'node_modules/.cache',
    ],
  },

  experimental: {
    // Next.js 16: optimizePackageImports moved to experimental
    // CRITICAL: @radix-ui/react-tabs is NOT included here because it was replaced
    // with a custom implementation to avoid createContext errors during build.
    // See src/components/ui/index.tsx for the custom Tabs implementation.
    optimizePackageImports: [
      'lucide-react',
      '@radix-ui/react-avatar',
      '@radix-ui/react-dialog',
      '@radix-ui/react-dropdown-menu',
      '@radix-ui/react-popover',
      '@radix-ui/react-scroll-area',
      '@radix-ui/react-select',
      '@radix-ui/react-switch',
      // '@radix-ui/react-tabs', // REMOVED: Using custom implementation instead
      '@radix-ui/react-tooltip',
    ],
  },

  // CRITICAL: Webpack configuration to prevent createContext errors during Docker build
  // The issue occurs because Next.js tries to analyze client-only packages during
  // the SSG build phase, which use React Context internally.
  webpack: (config, { isServer }) => {
    if (isServer) {
      // CRITICAL: On server build, exclude all client-only packages from being bundled
      // This prevents Next.js from trying to execute createContext during build
      config.externals = config.externals || [];
      const clientOnlyPackages = [
        'next-themes',
        'sonner',
        'framer-motion',
        'react-hot-toast',
        'swr',
        'zustand',
      ];
      if (Array.isArray(config.externals)) {
        config.externals.push(...clientOnlyPackages);
      } else if (typeof config.externals === 'function') {
        const originalExternals = config.externals;
        config.externals = ({ context, request }, callback) => {
          if (clientOnlyPackages.some(pkg => request === pkg || request.startsWith(pkg + '/'))) {
            return callback(null, 'commonjs ' + request);
          }
          return originalExternals({ context, request }, callback);
        };
      }
    } else {
      // Client-side: disable Node.js polyfills that aren't needed in browser
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        path: false,
        crypto: false,
      };
    }
    return config;
  },

  // Turbopack configuration for Next.js 16
  // Note: Using empty turbopack config to maintain webpack compatibility
  turbopack: {},

  typedRoutes: false,

  // CRITICAL: Mark all client-only packages as external for server components
  // This prevents createContext errors during Docker build when Next.js
  // tries to analyze client-only packages during the SSG phase
  serverExternalPackages: [
    'next-themes',
    'sonner',
    'framer-motion',
    'react-hot-toast',
    'swr',
    'zustand',
  ],

  // CRITICAL: Disable standalone output mode to fix Next.js 16 build errors
  // The standalone mode with Next.js 16 causes file tracing errors during build:
  // - ENOENT errors for .nft.json files (Next.js File Tracing)
  // - Missing .next/server/app/*/page.js.nft.json files
  // The Docker container will use the standard .next build output instead
  // output: 'standalone', // DISABLED: Causes file tracing errors in Next.js 16
};

module.exports = nextConfig;
