"use client";

import { CheckCircle, WarningCircle, X } from "@phosphor-icons/react/dist/ssr";

export type ToastVariant = "success" | "error";

export interface ToastItem {
  id: string;
  message: string;
  variant: ToastVariant;
}

const variantStyles: Record<ToastVariant, { icon: typeof CheckCircle; classes: string }> = {
  success: { icon: CheckCircle, classes: "border-success/25 bg-success/[0.1] text-success" },
  error: { icon: WarningCircle, classes: "border-error/25 bg-error-bg text-error" },
};

/** Small dismissible banner used for one-off confirmations (e.g. after a form submit) that
 * fades out on its own after a few seconds. See lib/toast/ToastProvider.tsx for the queue and
 * timing that drives `fading`. */
export function Toast({
  toast,
  fading,
  onDismiss,
}: {
  toast: ToastItem;
  fading: boolean;
  onDismiss: () => void;
}) {
  const { icon: Icon, classes } = variantStyles[toast.variant];

  return (
    <div
      role="status"
      className={`pointer-events-auto flex w-full max-w-md items-center gap-2.5 rounded-xl border px-4 py-3 shadow-lg transition-opacity duration-300 ${classes} ${
        fading ? "opacity-0" : "opacity-100"
      }`}
    >
      <Icon size={18} weight="fill" className="shrink-0" />
      <p className="flex-1 text-sm font-semibold">{toast.message}</p>
      <button
        type="button"
        onClick={onDismiss}
        aria-label="Dismiss"
        className="-m-1.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full hover:bg-black/5"
      >
        <X size={14} />
      </button>
    </div>
  );
}
