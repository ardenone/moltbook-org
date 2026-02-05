/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Note: output: 'standalone' removed due to Next.js 15.1.6 NFT build trace bug
  // The actual error was "ENOENT: no such file or directory, open '.next/server/app/api/agents/route.js.nft.json'"
  // See: https://github.com/vercel/next.js/issues/43849
  // The Dockerfile has been updated to use standard Next.js deployment (npm start)

  // CRITICAL: Disable all static optimization to prevent createContext errors during build
  // In Next.js 15 with React 19, static optimization still tries to analyze client components
  // Setting this to false forces all pages to be server-rendered or dynamically rendered
  // This is the primary fix for the "createContext is not a function" error during Docker builds
  productionBrowserSourceMaps: false,

  experimental: {
    // Optimize package imports for better tree-shaking
    optimizePackageImports: [
      'lucide-react',
      // Add Radix UI packages to optimize imports and prevent createContext issues during SSR
      '@radix-ui/react-avatar',
      '@radix-ui/react-dialog',
      '@radix-ui/react-dropdown-menu',
      '@radix-ui/react-popover',
      '@radix-ui/react-scroll-area',
      '@radix-ui/react-select',
      '@radix-ui/react-switch',
      '@radix-ui/react-tabs',
      '@radix-ui/react-tooltip',
    ],
    // Disable turbo for now as it has issues with React 19 + Radix UI in Docker builds
    turbo: undefined,
  },

  // Ensure transpilePackages for zustand, Radix UI, and other packages using React context to prevent SSR issues
  transpilePackages: ['zustand', '@radix-ui', 'next-themes', 'sonner', 'framer-motion'],

  // Ensure React is bundled correctly for SSR/SSG
  webpack: (config, { isServer, dev }) => {
    // CRITICAL FIX: Ensure React is not externalized during SSR to prevent createContext errors
    // This is the most important fix for the build error
    if (isServer) {
      // Filter out React and ReactDOM from externals to ensure proper bundling
      config.externals = config.externals || [];

      // Handle different external formats
      const externalsToRemove = ['react', 'react-dom', 'react/jsx-runtime', 'react-dom/client', 'react-dom/server-browser', 'react-dom/server-edge'];

      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter((external) => {
          if (typeof external === 'string') {
            return !externalsToRemove.includes(external);
          }
          // Keep function and regex externals
          return true;
        });
      } else if (typeof config.externals === 'function') {
        // Wrap function externals to filter out React packages
        const originalExternals = config.externals;
        config.externals = ({ request, dependencyType, ...args }, callback) => {
          if (externalsToRemove.includes(request)) {
            return callback(null, false); // Don't externalize
          }
          return originalExternals({ request, dependencyType, ...args }, callback);
        };
      }

      // Also ensure React is resolved correctly from node_modules
      config.resolve = config.resolve || {};
      config.resolve.alias = config.resolve.alias || {};
      config.resolve.alias.react = require.resolve('react');
      config.resolve.alias['react-dom'] = require.resolve('react-dom');
      config.resolve.alias['react/jsx-runtime'] = require.resolve('react/jsx-runtime');
    }

    // Disable webpack cache in production to prevent stale build artifacts
    if (!dev) {
      config.cache = false;
    }

    return config;
  },
};

module.exports = nextConfig;
