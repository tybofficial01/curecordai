"use client";

import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from "react";
import { Toast, type ToastItem, type ToastVariant } from "@/components/ui/Toast";

interface ShowToastOptions {
  message: string;
  variant?: ToastVariant;
}

type ShowToastFn = (options: ShowToastOptions) => void;

const ToastContext = createContext<ShowToastFn | null>(null);

const TOAST_VISIBLE_MS = 4000;
const TOAST_FADE_MS = 300;

/** Mounted once at the app root (see app/layout.tsx), the same level as ConfirmDialogProvider,
 * so a toast queued right before a client-side navigation (e.g. router.push after a successful
 * form submit) keeps rendering across the route change instead of being reset by it. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const [fadingIds, setFadingIds] = useState<Set<string>>(new Set());
  const nextId = useRef(0);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    setFadingIds((prev) => {
      if (!prev.has(id)) return prev;
      const next = new Set(prev);
      next.delete(id);
      return next;
    });
  }, []);

  const showToast = useCallback<ShowToastFn>(
    (options) => {
      const id = `toast-${nextId.current++}`;
      setToasts((prev) => [...prev, { id, message: options.message, variant: options.variant ?? "success" }]);

      setTimeout(() => {
        setFadingIds((prev) => new Set(prev).add(id));
        setTimeout(() => removeToast(id), TOAST_FADE_MS);
      }, TOAST_VISIBLE_MS);
    },
    [removeToast]
  );

  return (
    <ToastContext.Provider value={showToast}>
      {children}
      {toasts.length > 0 && (
        <div className="pointer-events-none fixed inset-x-0 top-4 z-[200] flex flex-col items-center gap-2 px-4">
          {toasts.map((toast) => (
            <Toast key={toast.id} toast={toast} fading={fadingIds.has(toast.id)} onDismiss={() => removeToast(toast.id)} />
          ))}
        </div>
      )}
    </ToastContext.Provider>
  );
}

/** Fire-and-forget toast trigger, no existing toast/snackbar system was found in the codebase
 * (searched app/, components/, lib/) so this mirrors the promise-based useConfirm() pattern in
 * lib/dialog/ConfirmDialogProvider.tsx, minus the promise since a toast has no result to wait on. */
export function useToast(): ShowToastFn {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within a ToastProvider");
  return ctx;
}
