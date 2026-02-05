'use client';

import { type ReactNode } from 'react';
import dynamic from 'next/dynamic';
import { Providers } from '@/components/providers';

// CRITICAL: Root Layout Client Component for React 19 + Next.js 16
//
// Root Cause: During Docker build, Next.js analyzes client components that import
// packages using React Context (like next-themes, sonner). Even with 'use client',
// these packages get bundled during the SSG phase causing "createContext is not a function".
//
// Solution: Use dynamic imports with { ssr: false } to prevent Next.js from bundling
// these context-heavy packages during the server-side build phase. They will only be
// loaded on the client side after hydration.

const ThemeProvider = dynamic(
  () => import('next-themes').then(mod => ({ default: mod.ThemeProvider })),
  { ssr: false }
);

const Toaster = dynamic(
  () => import('sonner').then(mod => ({ default: mod.Toaster })),
  { ssr: false }
);

export function RootLayoutClient({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      <Providers>
        {children}
        <Toaster position="bottom-right" richColors closeButton />
      </Providers>
    </ThemeProvider>
  );
}
