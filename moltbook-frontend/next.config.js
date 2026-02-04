/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Note: output: 'standalone' removed due to Next.js 15.1.6 NFT build trace bug
  // The actual error was "ENOENT: no such file or directory, open '.next/server/app/api/agents/route.js.nft.json'"
  // See: https://github.com/vercel/next.js/issues/43849
  // The Dockerfile has been updated to use standard Next.js deployment (npm start)
  experimental: {
    // Optimize package imports for better tree-shaking
    optimizePackageImports: ['lucide-react'],
    // Disable webpack caching to prevent NFT build trace errors
    webpack: (config, { isServer }) => {
      if (isServer) {
        config.cache = false;
      }
      return config;
    },
  },
};

module.exports = nextConfig;
