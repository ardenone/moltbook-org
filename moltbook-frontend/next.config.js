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

  // CRITICAL: Disable Turbopack to use webpack instead
  // Turbopack has workspace inference issues in certain environments
  // that cause "Next.js inferred your workspace root" errors.
  // By setting turbopack to null, we force Next.js to use webpack.
  turbopack: null,

  typedRoutes: false,

  // CRITICAL: Webpack configuration for Next.js 16
  // Fixes "Cannot read properties of undefined (reading 'issuerLayer')" error
  // that occurs during Docker builds with Next.js 16 + React 19.
  //
  // Also handles node: prefixed imports used by Next.js experimental testmode.
  // This fixes "Reading from node:async_hooks is not handled by plugins" error.
  webpack: (config, { isServer }) => {
    // CRITICAL: Ensure React and React DOM are always bundled and never externalized
    // This prevents useContext errors during server-side rendering/prerendering
    config.externals = config.externals || [];
    if (Array.isArray(config.externals)) {
      // Filter out any externals that might externalize react or react-dom
      config.externals = config.externals.map(external => {
        if (typeof external === 'function') {
          return ({ request }, callback) => {
            if (request === 'react' || request === 'react-dom' || request.startsWith('react/')) {
              return callback();
            }
            return external({ request }, callback);
          };
        }
        return external;
      });
    }

    // CRITICAL: Handle node: prefixed imports for Next.js testmode
    // Next.js 16 experimental testmode uses require("node:async_hooks") which
    // webpack cannot handle by default. Map node: prefixed imports to regular imports.
    config.resolve = config.resolve || {};
    config.resolve.alias = config.resolve.alias || {};
    const nodeModules = ['async_hooks', 'fs', 'path', 'crypto', 'stream', 'util', 'url', 'querystring', 'events', 'buffer', 'http', 'https', 'net', 'tls', 'child_process', 'os', 'cluster', 'worker_threads', 'zlib'];
    nodeModules.forEach(module => {
      config.resolve.alias[`node:${module}`] = module;
    });

    if (!isServer) {
      // Client-side: disable Node.js polyfills that aren't needed in browser
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        path: false,
        crypto: false,
        async_hooks: false,
      };
    }

    return config;
  },

  // CRITICAL: serverExternalPackages - kept for compatibility but not strictly needed
  // with React 19 + Next.js 16 when using 'force-dynamic' and proper 'use client' directives.
  // NOTE: React and React-DOM are NOT included here - they must always be bundled
  // to prevent "Cannot read properties of null (reading 'useContext')" errors.
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
