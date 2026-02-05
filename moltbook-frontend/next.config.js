/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  productionBrowserSourceMaps: false,

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

  // Empty turbopack config to silence the warning about webpack config without turbopack
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
};

module.exports = nextConfig;
