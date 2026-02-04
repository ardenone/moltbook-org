/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Note: output: 'standalone' removed due to Next.js 15.1.x NFT build trace bug
  // See: https://github.com/vercel/next.js/issues/43849
  // The Dockerfile has been updated to use standard Next.js deployment instead
  experimental: {
    // Optimize package imports for better tree-shaking
    optimizePackageImports: ['lucide-react'],
  },
};

module.exports = nextConfig;
