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
      // Ensure React is always bundled, never externalized
      config.externals = config.externals || [];
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter(
          (e) => typeof e === 'string' && e !== 'react' && e !== 'react-dom' && e !== 'react/jsx-runtime' && e !== 'react-dom/client' && e !== 'critters'
        );
      }
      // Add resolve alias to ensure correct React version is used
      config.resolve.alias = {
        ...config.resolve.alias,
        react: require.resolve('react'),
        'react-dom': require.resolve('react-dom'),
        'react/jsx-runtime': require.resolve('react/jsx-runtime'),
      };
      // Ensure critters is resolvable
      config.resolve.modules = [
        ...(config.resolve.modules || []),
        'node_modules',
      ];
    }
    return config;
  },
};

module.exports = nextConfig;
