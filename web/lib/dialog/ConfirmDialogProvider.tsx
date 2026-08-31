"use client";

import { createContext, useCallback, useContext, useState, type ReactNode } from "react";
import { ConfirmDialog, type ConfirmDialogOptions } from "@/components/ui/ConfirmDialog";

type ConfirmFn = (options: ConfirmDialogOptions) => Promise<boolean>;

const ConfirmDialogContext = createContext<ConfirmFn | null>(null);

type PendingConfirm = {
  options: ConfirmDialogOptions;
  resolve: (value: boolean) => void;
};

export function ConfirmDialogProvider({ children }: { children: ReactNode }) {
  const [pending, setPending] = useState<PendingConfirm | null>(null);

  const confirm = useCallback<ConfirmFn>((options) => {
    return new Promise<boolean>((resolve) => {
      setPending({ options, resolve });
    });
  }, []);

  function settle(result: boolean) {
    pending?.resolve(result);
    setPending(null);
  }

  return (
    <ConfirmDialogContext.Provider value={confirm}>
      {children}
      {pending && (
        <ConfirmDialog {...pending.options} onConfirm={() => settle(true)} onCancel={() => settle(false)} />
      )}
    </ConfirmDialogContext.Provider>
  );
}

/** Promise-based replacement for `window.confirm` styled to match the app's brand - resolves
 * `true`/`false` instead of blocking the thread, so call sites just add an `await`. */
export function useConfirm(): ConfirmFn {
  const ctx = useContext(ConfirmDialogContext);
  if (!ctx) throw new Error("useConfirm must be used within a ConfirmDialogProvider");
  return ctx;
}
