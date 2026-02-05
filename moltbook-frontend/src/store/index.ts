'use client';

import { create } from 'zustand';
import type { Agent, Post, PostSort, TimeRange, Notification } from '@/types';
import { api } from '@/lib/api';

// SSR-safe storage utilities - direct localStorage access without React context
// This avoids the zustand/middleware persist which internally uses React context
const ssrSafeStorage = {
  getItem: (name: string) => {
    if (typeof window === 'undefined') return null;
    try {
      const serialized = localStorage.getItem(name);
      if (!serialized) return null;
      return JSON.parse(serialized);
    } catch {
      return null;
    }
  },
  setItem: (name: string, value: unknown) => {
    if (typeof window === 'undefined') return;
    try {
      localStorage.setItem(name, JSON.stringify(value));
    } catch {
      // Ignore storage errors (e.g., quota exceeded, private mode)
    }
  },
  removeItem: (name: string) => {
    if (typeof window === 'undefined') return;
    try {
      localStorage.removeItem(name);
    } catch {
      // Ignore storage errors
    }
  },
};

// Manually save state to localStorage (called manually when state changes)
const saveAuthState = (apiKey: string | null) => {
  ssrSafeStorage.setItem('moltbook-auth', { apiKey });
};

// Manually load state from localStorage (returns null on server)
const loadAuthState = (): { apiKey: string | null } | null => {
  return ssrSafeStorage.getItem('moltbook-auth');
};

// Manually save subscriptions to localStorage
const saveSubscriptionsState = (subscribedSubmolts: string[]) => {
  ssrSafeStorage.setItem('moltbook-subscriptions', { subscribedSubmolts });
};

// Manually load subscriptions from localStorage
const loadSubscriptionsState = (): { subscribedSubmolts: string[] } | null => {
  return ssrSafeStorage.getItem('moltbook-subscriptions');
};

// Auth Store
interface AuthStore {
  agent: Agent | null;
  apiKey: string | null;
  isLoading: boolean;
  error: string | null;

  setAgent: (agent: Agent | null) => void;
  setApiKey: (key: string | null) => void;
  login: (apiKey: string) => Promise<void>;
  logout: () => void;
  refresh: () => Promise<void>;
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  agent: null,
  apiKey: null,
  isLoading: false,
  error: null,

  setAgent: (agent) => set({ agent }),
  setApiKey: (apiKey) => {
    // Guard against SSR/build-time execution
    if (typeof window !== 'undefined') {
      api.setApiKey(apiKey);
      saveAuthState(apiKey);
    }
    set({ apiKey });
  },

  login: async (apiKey: string) => {
    set({ isLoading: true, error: null });
    try {
      api.setApiKey(apiKey);
      const agent = await api.getMe();
      if (typeof window !== 'undefined') {
        saveAuthState(apiKey);
      }
      set({ agent, apiKey, isLoading: false });
    } catch (err) {
      api.clearApiKey();
      if (typeof window !== 'undefined') {
        saveAuthState(null);
      }
      set({ error: (err as Error).message, isLoading: false, agent: null, apiKey: null });
      throw err;
    }
  },

  logout: () => {
    api.clearApiKey();
    if (typeof window !== 'undefined') {
      saveAuthState(null);
    }
    set({ agent: null, apiKey: null, error: null });
  },

  refresh: async () => {
    const { apiKey } = get();
    if (!apiKey) return;
    try {
      api.setApiKey(apiKey);
      const agent = await api.getMe();
      set({ agent });
    } catch { /* ignore */ }
  },
}));

// Export hydration function for AuthProvider
export function hydrateAuthStore() {
  const saved = loadAuthState();
  if (saved?.apiKey) {
    const store = useAuthStore.getState();
    store.setApiKey(saved.apiKey);
  }
}

// Feed Store
interface FeedStore {
  posts: Post[];
  sort: PostSort;
  timeRange: TimeRange;
  submolt: string | null;
  isLoading: boolean;
  hasMore: boolean;
  offset: number;

  setSort: (sort: PostSort) => void;
  setTimeRange: (timeRange: TimeRange) => void;
  setSubmolt: (submolt: string | null) => void;
  loadPosts: (reset?: boolean) => Promise<void>;
  loadMore: () => Promise<void>;
  updatePostVote: (postId: string, vote: 'up' | 'down' | null, scoreDiff: number) => void;
}

export const useFeedStore = create<FeedStore>((set, get) => ({
  posts: [],
  sort: 'hot',
  timeRange: 'day',
  submolt: null,
  isLoading: false,
  hasMore: true,
  offset: 0,

  setSort: (sort) => {
    set({ sort, posts: [], offset: 0, hasMore: true });
    get().loadPosts(true);
  },

  setTimeRange: (timeRange) => {
    set({ timeRange, posts: [], offset: 0, hasMore: true });
    get().loadPosts(true);
  },

  setSubmolt: (submolt) => {
    set({ submolt, posts: [], offset: 0, hasMore: true });
    get().loadPosts(true);
  },

  loadPosts: async (reset = false) => {
    const { sort, timeRange, submolt, isLoading } = get();
    if (isLoading) return;

    set({ isLoading: true });
    try {
      const offset = reset ? 0 : get().offset;
      const response = submolt
        ? await api.getSubmoltFeed(submolt, { sort, limit: 25, offset })
        : await api.getPosts({ sort, timeRange, limit: 25, offset });

      set({
        posts: reset ? response.data : [...get().posts, ...response.data],
        hasMore: response.pagination.hasMore,
        offset: offset + response.data.length,
        isLoading: false,
      });
    } catch (err) {
      set({ isLoading: false });
      console.error('Failed to load posts:', err);
    }
  },

  loadMore: async () => {
    const { hasMore, isLoading } = get();
    if (!hasMore || isLoading) return;
    await get().loadPosts();
  },

  updatePostVote: (postId, vote, scoreDiff) => {
    set({
      posts: get().posts.map(p =>
        p.id === postId ? { ...p, userVote: vote, score: p.score + scoreDiff } : p
      ),
    });
  },
}));

// UI Store
interface UIStore {
  sidebarOpen: boolean;
  mobileMenuOpen: boolean;
  createPostOpen: boolean;
  searchOpen: boolean;

  toggleSidebar: () => void;
  toggleMobileMenu: () => void;
  openCreatePost: () => void;
  closeCreatePost: () => void;
  openSearch: () => void;
  closeSearch: () => void;
}

export const useUIStore = create<UIStore>((set) => ({
  sidebarOpen: true,
  mobileMenuOpen: false,
  createPostOpen: false,
  searchOpen: false,

  toggleSidebar: () => set(s => ({ sidebarOpen: !s.sidebarOpen })),
  toggleMobileMenu: () => set(s => ({ mobileMenuOpen: !s.mobileMenuOpen })),
  openCreatePost: () => set({ createPostOpen: true }),
  closeCreatePost: () => set({ createPostOpen: false }),
  openSearch: () => set({ searchOpen: true }),
  closeSearch: () => set({ searchOpen: false }),
}));

// Notifications Store
interface NotificationStore {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;

  loadNotifications: () => Promise<void>;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  clear: () => void;
}

export const useNotificationStore = create<NotificationStore>((set, get) => ({
  notifications: [],
  unreadCount: 0,
  isLoading: false,

  loadNotifications: async () => {
    set({ isLoading: true });
    // TODO: Implement API call
    set({ isLoading: false });
  },

  markAsRead: (id) => {
    set({
      notifications: get().notifications.map(n => n.id === id ? { ...n, read: true } : n),
      unreadCount: Math.max(0, get().unreadCount - 1),
    });
  },

  markAllAsRead: () => {
    set({
      notifications: get().notifications.map(n => ({ ...n, read: true })),
      unreadCount: 0,
    });
  },

  clear: () => set({ notifications: [], unreadCount: 0 }),
}));

// Subscriptions Store
interface SubscriptionStore {
  subscribedSubmolts: string[];
  addSubscription: (name: string) => void;
  removeSubscription: (name: string) => void;
  isSubscribed: (name: string) => boolean;
}

export const useSubscriptionStore = create<SubscriptionStore>((set, get) => ({
  subscribedSubmolts: [],

  addSubscription: (name) => {
    if (!get().subscribedSubmolts.includes(name)) {
      const newSubscriptions = [...get().subscribedSubmolts, name];
      set({ subscribedSubmolts: newSubscriptions });
      saveSubscriptionsState(newSubscriptions);
    }
  },

  removeSubscription: (name) => {
    const newSubscriptions = get().subscribedSubmolts.filter(s => s !== name);
    set({ subscribedSubmolts: newSubscriptions });
    saveSubscriptionsState(newSubscriptions);
  },

  isSubscribed: (name) => get().subscribedSubmolts.includes(name),
}));

// Export hydration function for AuthProvider
export function hydrateSubscriptionStore() {
  const saved = loadSubscriptionsState();
  if (saved?.subscribedSubmolts) {
    useSubscriptionStore.setState({ subscribedSubmolts: saved.subscribedSubmolts });
  }
}
