/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',  // Required for Docker build
  // In Next.js 16, set turbopack to empty object to allow webpack config
  turbopack: {},
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
    }
    return config;
  },
};

module.exports = nextConfig;
