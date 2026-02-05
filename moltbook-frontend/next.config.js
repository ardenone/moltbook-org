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

  // CRITICAL: Turbopack configuration for Next.js 16
  // Using Turbopack instead of webpack to avoid compatibility issues with
  // node: prefixed imports in Next.js experimental testmode.
  // Turbopack properly handles Node.js protocol prefixed imports (node:async_hooks)
  // that webpack fails to handle correctly during Docker builds.
  // Note: The build script uses --turbopack flag explicitly
  turbopack: {
    // Explicitly set the root directory to avoid workspace inference errors
    root: __dirname,
  },

  typedRoutes: false,

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
