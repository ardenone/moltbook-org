/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Ensure React is bundled correctly
  transpilePackages: [],
  webpack: (config, { isServer }) => {
    // Handle node: prefixed modules properly
    if (isServer) {
      // Ensure React is not externalized
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter(
          (e) => typeof e === 'string' && !e.startsWith('react')
        );
      }

      // Configure webpack to handle node: prefixed modules
      // These should be treated as externals (Node.js built-ins)
      config.externals = config.externals || [];
      const originalExternals = Array.isArray(config.externals)
        ? config.externals
        : [config.externals];

      // Add a function external to handle node: prefixed modules
      config.externals = [
        ...originalExternals.filter(e => typeof e !== 'function'),
        function({ request }, callback) {
          // Mark node: prefixed modules as external (strip the node: prefix)
          if (typeof request === 'string' && request.startsWith('node:')) {
            return callback(null, 'commonjs ' + request.slice(5));
          }
          // For non-function externals in the array, call them
          if (originalExternals.length > 0) {
            const funcExternals = originalExternals.filter(e => typeof e === 'function');
            if (funcExternals.length > 0) {
              return funcExternals[0]({ request }, callback);
            }
          }
          return callback();
        },
      ];
    }

    // Disable warnings about problematic Next.js experimental testmode modules
    config.ignoreWarnings = [
      {
        module: /node_modules[\\/]next[\\/]dist[\\/]experimental[\\/]testmode/,
      },
    ];

    return config;
  },
};

module.exports = nextConfig;
