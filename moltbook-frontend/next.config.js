/** @type {import('next').NextConfig} */
const nextConfig = {
  // Disable reactStrictMode for React 19 + Next.js 16
  reactStrictMode: false,

  productionBrowserSourceMaps: false,

  // Disable static image optimization for container deployment
  images: {
    unoptimized: true,
  },

  // Experimental options for Next.js 16
  experimental: {
    optimizePackageImports: [
      'lucide-react',
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

  // Mark client-only packages as external for server components
  serverExternalPackages: [
    'next-themes',
    'sonner',
    'framer-motion',
    'react-hot-toast',
    'swr',
    'zustand',
  ],

  // Output mode for container deployment
  output: 'standalone',
};

module.exports = nextConfig;
