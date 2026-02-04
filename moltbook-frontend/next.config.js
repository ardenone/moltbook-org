/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Use empty Turbopack config to silence warning about webpack config in Next.js 16
  turbopack: {},
};

module.exports = nextConfig;
