/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  experimental: {
    // Force all pages to be dynamic to avoid SSG build issues with client context
    isrMemoryCacheSize: 0,
  },
};

module.exports = nextConfig;
