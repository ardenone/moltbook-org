'use client';

import { type ReactNode } from 'react';
import { ThemeProvider } from 'next-themes';
import { Toaster } from 'sonner';
import { Providers } from '@/components/providers';

// CRITICAL: Root Layout Client Component for React 19 + Next.js 15
//
// Root Cause: In Next.js 15 with React 19, the 'ssr: false' option for dynamic imports
// is deprecated and causes build errors. Context APIs work correctly in React 19 when
// components are properly marked with 'use client'.
//
// Solution: Direct imports work correctly with React 19 + Next.js 15. The 'use client'
// directive ensures these components only run on the client side.

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
