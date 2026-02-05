'use client';

import { type ReactNode } from 'react';
import dynamic from 'next/dynamic';

// CRITICAL: Dynamic imports with ssr: false prevent createContext errors during Docker build
//
// Root Cause: Even with 'use client' and export const dynamic = 'force-dynamic',
// Next.js 15 still attempts to execute client components during build for optimization.
// Components using React Context (ThemeProvider, Toaster, Providers) fail because
// React Context APIs are not available in the Node.js build environment.
//
// Solution: Use dynamic imports with ssr: false to completely skip server-side rendering
// and prevent these components from being executed during the Docker build.

const ThemeProvider = dynamic(
  () => import('next-themes').then(mod => ({ default: mod.ThemeProvider })),
  { ssr: false }
);

const Toaster = dynamic(
  () => import('sonner').then(mod => ({ default: mod.Toaster })),
  { ssr: false }
);

const Providers = dynamic(
  () => import('@/components/providers').then(mod => ({ default: mod.Providers })),
  {
    ssr: false,
    loading: () => null, // Don't render anything during initial load
  }
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
