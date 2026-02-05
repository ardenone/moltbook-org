import type { ReactNode } from 'react';
import { MainLayout } from '@/components/layout';

// CRITICAL: Direct import of MainLayout for React 19 + Next.js 15
//
// Root Cause: In Next.js 15 with React 19, the 'ssr: false' option for dynamic imports
// is deprecated and causes build errors. Additionally, naming 'export const dynamic'
// conflicts with the 'dynamic' import from Next.js.
//
// Solution: Direct imports work correctly with React 19 + Next.js 15 when components
// are properly marked with 'use client' directive. The MainLayout component has this
// directive, so it will only render on the client side.

// Force dynamic rendering for all pages in this group to avoid SSG build issues
export const dynamic = 'force-dynamic';

export default function MainGroupLayout({ children }: { children: ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
