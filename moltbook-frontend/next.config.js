/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Disable ISR memory cache (deprecated in Next.js 15)
  // Note: isrMemoryCacheSize is deprecated and causes warnings
  experimental: {},
  // Ensure React is bundled correctly
  transpilePackages: [],
  webpack: (config, { isServer }) => {
    // Fix for createContext bundling issue during Docker build
    if (isServer) {
      // Don't externalize swr and @tanstack/react-query - they use React Context
      // which requires proper bundling
      // config.externals = [...(config.externals || []), 'swr', '@tanstack/react-query'];
    }
    return config;
  },
};

module.exports = nextConfig;
