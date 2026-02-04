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
    // Fix for createContext and react/jsx-runtime bundling issue during Docker build
    if (isServer) {
      // Don't externalize React-related packages
      // Next.js should handle React bundling correctly
      // Just ensure externals don't include react or react-dom
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter(
          (e) => typeof e === 'string' &&
          e !== 'react' &&
          e !== 'react-dom' &&
          e !== 'react/jsx-runtime' &&
          e !== 'react-dom/client' &&
          !e.startsWith('react/')
        );
      }

      // Ensure fallback for react modules in case they're not found
      config.resolve.fallback = {
        ...config.resolve.fallback,
        react: false,
        'react-dom': false,
        'react/jsx-runtime': false,
      };
    }
    return config;
  },
};

module.exports = nextConfig;
