/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Disable standalone output - the Dockerfile will build properly without it
  // This fixes the "Cannot read properties of null (reading 'useContext')" error
  // that occurs during static page generation in Next.js 15 with standalone output
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
