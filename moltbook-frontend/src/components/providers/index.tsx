'use client';

import { useState, useEffect, type ReactNode } from 'react';
import { useAuthStore, useSubscriptionStore, hydrateAuthStore, hydrateSubscriptionStore } from '@/store';
import { api } from '@/lib/api';

// CRITICAL: Auth Provider with SSR-safe initialization
//
// This provider is designed to work correctly in Docker builds where Next.js
// may attempt to analyze client components during the build phase. The key
// safeguards are:
// 1. Check for window/document/browser APIs before use
// 2. Use lazy initialization to prevent execution during build
// 3. Avoid accessing Context providers during module evaluation

// Auth provider to initialize auth state
function AuthProvider({ children }: { children: ReactNode }) {
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    // Only run on client side
    if (typeof window === 'undefined') return;

    const init = async () => {
      try {
        // Manually hydrate zustand stores from localStorage
        // This uses custom hydration instead of zustand/middleware persist
        // which internally uses React context and fails during Next.js build
        hydrateAuthStore();
        hydrateSubscriptionStore();

        // After hydration, if we have an apiKey, refresh the agent data
        // Access store state AFTER hydration to avoid accessing uninitialized state
        const state = useAuthStore.getState();
        const { apiKey } = state;
        if (apiKey) {
          api.setApiKey(apiKey);
          try {
            await useAuthStore.getState().refresh();
          } catch {
            // Ignore refresh errors - token might be invalid
          }
        }
      } finally {
        setIsInitialized(true);
      }
    };

    init();
  }, []); // Empty deps - run once on mount

  // During SSR/build, render children immediately
  // On client, show loading until initialized
  if (typeof window !== 'undefined' && !isInitialized) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" />
      </div>
    );
  }

  return <>{children}</>;
}

// Analytics provider (placeholder)
function AnalyticsProvider({ children }: { children: ReactNode }) {
  // SSR-safe pathname access
  const pathname = typeof window !== 'undefined' ? window.location.pathname : '';

  useEffect(() => {
    // Track page views
    // console.log('Page view:', pathname);
    // Add your analytics tracking here (GA, Posthog, etc.)
  }, [pathname]);

  return <>{children}</>;
}

// Main providers wrapper
export function Providers({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <AnalyticsProvider>
        {children}
      </AnalyticsProvider>
    </AuthProvider>
  );
}
