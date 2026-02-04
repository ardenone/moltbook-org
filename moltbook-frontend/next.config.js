/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Use webpack explicitly for Next.js 16 compatibility
  // We have custom webpack config for node: prefix resolution
  webpack: (config, { isServer }) => {
    if (isServer) {
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
      // This ensures React is resolved correctly in server-side chunks
      config.resolve.mainFields = ['module', 'main'];
    }
    return config;
  },
};

module.exports = nextConfig;
