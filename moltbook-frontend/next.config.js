/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',  // Required for Docker build
  // Explicitly disable Turbopack to use webpack
  // In Next.js 16, Turbopack is enabled by default
  experimental: {
    turbo: undefined,
  },
};

module.exports = nextConfig;
