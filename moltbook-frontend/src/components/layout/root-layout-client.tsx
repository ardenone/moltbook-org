'use client';

import { type ReactNode } from 'react';
import { ThemeProvider } from 'next-themes';
import { Toaster } from 'sonner';
import { Providers } from '@/components/providers';

export function RootLayoutClient({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange suppressHydrationWarning>
      <Providers>
        {children}
        <Toaster position="bottom-right" richColors closeButton />
      </Providers>
    </ThemeProvider>
  );
}
