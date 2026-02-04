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

    // Fix for node: prefix handling - allow webpack to handle Node.js built-in modules with node: prefix
    // This fixes issues like "Reading from 'node:async_hooks' is not handled by plugins"
    if (typeof config.externals === 'function') {
      const originalExternals = config.externals;
      config.externals = ({ request }, callback) => {
        // Strip node: prefix before passing to the external function
        if (request && typeof request === 'string' && request.startsWith('node:')) {
          return originalExternals({ request: request.slice(5) }, callback);
        }
        return originalExternals({ request }, callback);
      };
    }

    return config;
  },
};

module.exports = nextConfig;
