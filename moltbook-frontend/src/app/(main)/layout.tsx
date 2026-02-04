// Force dynamic rendering for all pages in this group to avoid SSG build issues with client-side state
export const dynamic = 'force-dynamic';

import { MainLayout } from '@/components/layout';

export default function MainGroupLayout({ children }: { children: React.ReactNode }) {
  return <MainLayout>{children}</MainLayout>;
}
