/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  experimental: {
    // Disable server minification to fix "Failed to collect page data for /_not-found" build error in Next.js 15
    // See: https://github.com/vercel/next.js/discussions/74884
    serverMinification: false,
    // Optimize package imports for better tree-shaking
    optimizePackageImports: ['lucide-react'],
  },
};

module.exports = nextConfig;
