import type { ReactNode } from 'react';
import dynamic from 'next/dynamic';

// CRITICAL: Dynamic import with ssr: false prevents createContext errors during Docker build
//
// Root Cause: MainLayout is a client component that uses React hooks (useState, useEffect, usePathname, etc.)
// and store hooks (useAuthStore, useUIStore, useNotificationStore). When imported directly in a server component
// layout, Next.js 15 attempts to execute it during build for optimization, even with 'use client' directive
// and export const dynamic = 'force-dynamic'. This causes React Context APIs to be called in the Node.js
// build environment where they're not available.
//
// Solution: Use dynamic import with ssr: false to completely skip server-side rendering and prevent
// MainLayout from being executed during the Docker build phase.

const MainLayout = dynamic(
  () => import('@/components/layout').then(mod => ({ default: mod.MainLayout })),
  {
    ssr: false,
    loading: () => null,
  }
);

// Force dynamic rendering for all pages in this group to avoid SSG build issues
export const dynamic = 'force-dynamic';

export default function MainGroupLayout({ children }: { children: ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
