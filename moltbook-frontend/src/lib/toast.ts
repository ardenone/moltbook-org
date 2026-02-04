// Client-side toast utility to avoid SSR issues with sonner
let toastModule: any = null;

async function getToast() {
  if (!toastModule) {
    toastModule = await import('sonner');
  }
  return toastModule.toast;
}

export const toast = {
  success: async (message: string, ...args: any[]) => {
    if (typeof window === 'undefined') return;
    const t = await getToast();
    t.success(message, ...args);
  },
  error: async (message: string, ...args: any[]) => {
    if (typeof window === 'undefined') return;
    const t = await getToast();
    t.error(message, ...args);
  },
  info: async (message: string, ...args: any[]) => {
    if (typeof window === 'undefined') return;
    const t = await getToast();
    t.info(message, ...args);
  },
  promise: async <T,>(
    promise: Promise<T>,
    ...args: any[]
  ) => {
    if (typeof window === 'undefined') return promise;
    const t = await getToast();
    return t.promise(promise, ...args);
  },
};
