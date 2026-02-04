/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: [],
  experimental: {
    serverComponentsExternalPackages: [],
  },
  webpack: (config, { isServer }) => {
    if (isServer) {
      config.externals = [...(config.externals || []), 'swr', '@tanstack/react-query'];
    }
    return config;
  },
};

module.exports = nextConfig;
