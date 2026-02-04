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
        ? [...config.externals]
        : [config.externals];

      // Add a function external to handle node: prefixed modules
      config.externals = [
        ...originalExternals.filter(e => typeof e !== 'function'),
        function({ request }, callback) {
          // Mark node: prefixed modules as external (strip the node: prefix)
          if (typeof request === 'string' && request.startsWith('node:')) {
            return callback(null, 'commonjs ' + request.slice(5));
          }
          callback();
        },
      ];
    }

    // Add fallback for node: prefixed modules that webpack doesn't understand
    config.resolve = config.resolve || {};
    config.resolve.fallback = config.resolve.fallback || {};
    // List of Node.js built-ins that might use node: prefix
    const nodeBuiltins = [
      'async_hooks', 'fs', 'path', 'crypto', 'stream', 'util',
      'events', 'buffer', 'http', 'https', 'net', 'tls', 'os'
    ];
    nodeBuiltins.forEach(module => {
      if (!config.resolve.fallback[module]) {
        config.resolve.fallback[module] = false;
      }
    });

    // Disable warnings about problematic Next.js experimental testmode modules
    config.ignoreWarnings = [
      {
        module: /node_modules[\\/]next[\\/]dist[\\/]experimental[\\/]testmode/,
      },
      {
        message: /node:async_hooks/,
      },
    ];

    return config;
  },
};

module.exports = nextConfig;
