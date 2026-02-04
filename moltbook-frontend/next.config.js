/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // Ensure proper module resolution for standalone builds
  // This helps prevent "createContext is not a function" errors during build
  experimental: {
    // Disable server minification to fix "Failed to collect page data" build errors in Next.js 15
    // See: https://github.com/vercel/next.js/discussions/74884
    serverMinification: false,
    // Optimize package imports for better tree-shaking
    optimizePackageImports: ['lucide-react'],
  },
};

module.exports = nextConfig;
