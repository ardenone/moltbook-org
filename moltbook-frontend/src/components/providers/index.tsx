'use client';

import { useState, useEffect, type ReactNode } from 'react';
import { useAuthStore, useSubscriptionStore } from '@/store';
import { api } from '@/lib/api';

// Auth provider to initialize auth state
function AuthProvider({ children }: { children: ReactNode }) {
  const { apiKey, refresh } = useAuthStore();
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    const init = async () => {
      // Manually hydrate zustand stores since we use skipHydration: true
      // This prevents SSR "createContext is not a function" errors during build
      useAuthStore.persist.rehydrate();
      useSubscriptionStore.persist.rehydrate();

      // After hydration, if we have an apiKey, refresh the agent data
      if (apiKey) {
        api.setApiKey(apiKey);
        try {
          await refresh();
        } catch {
          // Ignore refresh errors - token might be invalid
        }
      }
      setIsInitialized(true);
    };
    init();
  }, [apiKey, refresh]);

  if (!isInitialized) {
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
