/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  productionBrowserSourceMaps: false,

  images: {
    unoptimized: true,
  },

  // Disable standalone output - use standard Next.js build for container
  // Standalone mode can cause issues with certain React 19 + Next.js 15 combinations
  // The Dockerfile already handles copying necessary files
  // output: 'standalone',

  // Disable file tracing to prevent build errors with Next.js 15
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

  // Explicitly disable turbopack to prevent webpack/turbopack conflicts
  // Using the standard webpack compiler which is more stable
  // --turbo flag in package.json scripts is also disabled
  turbo: undefined,

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
    // Disable typed routes to prevent build errors
    typedRoutes: false,
  },

  // Ensure webpack configuration is stable
  webpack: (config, { isServer }) => {
    // Fix for React 19 + Next.js 15 compatibility
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
