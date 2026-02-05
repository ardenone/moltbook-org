'use client';

import { type ReactNode } from 'react';
import dynamic from 'next/dynamic';

const MainLayout = dynamic(
  () => import('./index').then(mod => ({ default: mod.MainLayout })),
  {
    ssr: false,
    loading: () => null,
  }
);

export function MainLayoutClient({ children }: { children: ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
