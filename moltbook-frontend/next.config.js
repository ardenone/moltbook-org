/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  productionBrowserSourceMaps: false,

  images: {
    unoptimized: true,
  },

  // CRITICAL: Disable file tracing to prevent build errors with Next.js 15
  // Next.js 15 + React 19 may execute client-side code during build phase
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
    typedRoutes: false,
    // CRITICAL: Mark all client-only packages as external for server components
    // This prevents createContext errors during Docker build when Next.js
    // tries to analyze client-only packages during the SSG phase
    serverComponentsExternalPackages: [
      'next-themes',
      'sonner',
      'framer-motion',
      'react-hot-toast',
      'swr',
    ],
  },

  // Webpack configuration for React 19 + Next.js 15 compatibility
  webpack: (config, { isServer }) => {
    // CRITICAL FIX: Force all client-only packages to be external on server
    // This prevents createContext errors during Docker build
    if (isServer) {
      config.externals = config.externals || [];
      // Use object pattern for externals to properly exclude client-only packages
      const clientOnlyPackages = [
        'next-themes',
        'sonner',
        'framer-motion',
        'react-hot-toast',
        'swr',
      ];
      if (Array.isArray(config.externals)) {
        config.externals.push(
          ...clientOnlyPackages.map(pkg => ({
            [pkg]: pkg,
          }))
        );
      } else if (typeof config.externals === 'function') {
        const originalExternals = config.externals;
        config.externals = ({ context, request }, callback) => {
          if (clientOnlyPackages.includes(request)) {
            return callback(null, request);
          }
          return originalExternals({ context, request }, callback);
        };
      }
    }

    // Client-side webpack config
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        path: false,
        crypto: false,
      };
    }

    return config;
  },
};

module.exports = nextConfig;
