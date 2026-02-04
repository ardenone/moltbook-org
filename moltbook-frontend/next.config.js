/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Disable ISR memory cache (deprecated in Next.js 15)
  // Note: isrMemoryCacheSize is deprecated and causes warnings
  experimental: {},
  // Ensure React is bundled correctly
  transpilePackages: [],
  // Use webpack instead of Turbopack for compatibility
  webpack: (config, { isServer }) => {
    // Minimal webpack configuration to avoid breaking Next.js internals
    if (isServer) {
      // Ensure React is not externalized
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter(
          (e) => typeof e === 'string' && !e.startsWith('react')
        );
      }
    }
    return config;
  },
  // Explicitly disable Turbopack to use webpack
  experimental: {
    turbo: undefined,
  },
};

module.exports = nextConfig;
