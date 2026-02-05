/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Note: output: 'standalone' removed due to Next.js 15.1.6 NFT build trace bug
  // The actual error was "ENOENT: no such file or directory, open '.next/server/app/api/agents/route.js.nft.json'"
  // See: https://github.com/vercel/next.js/issues/43849
  // The Dockerfile has been updated to use standard Next.js deployment (npm start)
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
  },
  // Ensure transpilePackages for zustand, Radix UI, and other packages using React context to prevent SSR issues
  transpilePackages: ['zustand', '@radix-ui', 'next-themes', 'sonner', 'framer-motion'],
  // Ensure React is bundled correctly for SSR/SSG
  webpack: (config, { isServer }) => {
    // Ensure React is not externalized during SSR to prevent createContext errors
    if (isServer) {
      // Filter out React and ReactDOM from externals to ensure proper bundling
      config.externals = config.externals || [];
      if (Array.isArray(config.externals)) {
        config.externals = config.externals.filter(
          (external) => {
            // Handle string externals
            if (typeof external === 'string') {
              return !['react', 'react-dom', 'react/jsx-runtime', 'react-dom/client'].includes(external);
            }
            // Keep non-string externals (like functions and regex patterns)
            return true;
          }
        );
      }
      // Also ensure React is resolved correctly
      config.resolve = config.resolve || {};
      config.resolve.alias = config.resolve.alias || {};
      config.resolve.alias.react = require.resolve('react');
      config.resolve.alias['react-dom'] = require.resolve('react-dom');
    }
    return config;
  },
};

module.exports = nextConfig;
