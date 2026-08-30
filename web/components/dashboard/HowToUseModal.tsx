"use client";

import { useEffect } from "react";
import { Brain, ChatCircleDots, FileText, Paperclip, WarningCircle, X } from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";

function items(dm: DashboardMessages): { icon: Icon; title: string; description: string }[] {
  return [
    { icon: ChatCircleDots, title: dm.assistant.howTo.askTitle, description: dm.assistant.howTo.askDescription },
    { icon: Paperclip, title: dm.assistant.howTo.attachTitle, description: dm.assistant.howTo.attachDescription },
    { icon: FileText, title: dm.assistant.howTo.summarizeTitle, description: dm.assistant.howTo.summarizeDescription },
    { icon: Brain, title: dm.assistant.howTo.understandTitle, description: dm.assistant.howTo.understandDescription },
  ];
}

export function HowToUseModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const dm = useDashboardMessages();
  useEffect(() => {
    if (!open) return;
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", handleKeyDown);
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = overflow;
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="how-to-use-title"
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="how-to-use-title" className="text-base font-semibold text-ink">
            {dm.assistant.howTo.title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label={dm.common.close}
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-ink max-lg:h-11 max-lg:w-11"
          >
            <X size={16} />
          </button>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {items(dm).map((item) => (
            <div key={item.title} className="flex flex-col gap-2 rounded-xl border border-border bg-surface p-4">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-primary-tint text-primary">
                <item.icon size={18} />
              </span>
              <p className="text-sm font-semibold text-ink">{item.title}</p>
              <p className="text-xs leading-relaxed text-ink-muted">{item.description}</p>
            </div>
          ))}
        </div>

        <div className="mt-5 flex items-center gap-2 rounded-xl bg-primary-tint/50 px-4 py-3 text-xs text-ink-muted">
          <WarningCircle size={16} className="shrink-0 text-primary" />
          {dm.assistant.disclaimer}
        </div>

        <div className="mt-6 flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            {dm.common.gotIt}
          </button>
        </div>
      </div>
    </div>
  );
}
