import type { ReactNode } from 'react';
import { MainLayout } from '@/components/layout';

// Force dynamic rendering for all pages in this group to avoid SSG build issues
export const dynamic = 'force-dynamic';

export default function MainGroupLayout({ children }: { children: ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
