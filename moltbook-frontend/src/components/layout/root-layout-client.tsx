'use client';

import { type ReactNode } from 'react';
import { Providers } from '@/components/providers';

// CRITICAL: Root Layout Client Component for React 19 + Next.js 16
//
// Root Cause: During Docker build, Next.js analyzes client components that import
// packages using React Context (like next-themes, sonner). The 'ssr: false' option
// for dynamic imports is deprecated in Next.js 16 with React 19.
//
// Solution: With React 19 + Next.js 16, direct imports work correctly. The 'use client'
// directive ensures this component only runs on the client side. React 19's improved
// SSR handling properly separates server and client component boundaries.

import { ThemeProvider } from 'next-themes';
import { Toaster } from 'sonner';

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
