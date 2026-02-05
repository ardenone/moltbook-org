import { MainLayout } from '@/components/layout';
import type { ReactNode } from 'react';

// Force dynamic rendering for all pages in this group to avoid SSG build issues with client-side state
export const dynamic = 'force-dynamic';

export default function MainGroupLayout({ children }: { children: ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
