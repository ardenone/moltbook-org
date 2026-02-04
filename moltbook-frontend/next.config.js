/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Use webpack explicitly for Next.js 15 compatibility
  // We have custom webpack config for node: prefix resolution
  webpack: (config, { isServer }) => {
    // Add resolve alias to strip node: prefix during module resolution
    // This fixes "Reading from 'node:async_hooks' is not handled by plugins"
    config.resolve.alias = {
      ...config.resolve.alias,
      'node:async_hooks': 'async_hooks',
      'node:fs': 'fs',
      'node:path': 'path',
      'node:crypto': 'crypto',
      'node:stream': 'stream',
      'node:util': 'util',
      'node:events': 'events',
      'node:buffer': 'buffer',
      'node:http': 'http',
      'node:https': 'https',
    };

    // Fix for "TypeError: (0 , n.createContext) is not a function"
    // This ensures React is resolved correctly in both server and client bundles
    // The issue occurs when webpack minifies code and doesn't properly resolve React exports
    config.resolve.mainFields = ['module', 'main'];
    config.resolve.extensionAlias = {
      '.js': ['.js', '.tsx', '.ts'],
    };

    // Ensure React is treated as an external module in server builds
    // This prevents bundling React multiple times which causes createContext issues
    if (isServer) {
      config.externals = config.externals || [];
      // Don't externalize React in Next.js server components
      // Instead, ensure it's resolved from the same React instance
    }

    return config;
  },
};

module.exports = nextConfig;
