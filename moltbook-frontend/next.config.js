/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Disable build-time optimizations that cause createContext bundling issues
  generateBuildId: undefined,
  experimental: {
    // Force all pages to be dynamic to avoid SSG build issues with client context
    isrMemoryCacheSize: 0,
  },
  // Ensure React is bundled correctly
  transpilePackages: [],
  webpack: (config, { isServer }) => {
    // Fix for createContext bundling issue during Docker build
    if (isServer) {
      config.externals = [...(config.externals || []), 'swr', '@tanstack/react-query'];
      // Ensure React is treated as an internal module, not external
      const externals = Array.isArray(config.externals) ? config.externals : [config.externals];
      config.externals = externals.filter(e => e !== 'react' && e !== 'react-dom');
    }
    return config;
  },
};

module.exports = nextConfig;
