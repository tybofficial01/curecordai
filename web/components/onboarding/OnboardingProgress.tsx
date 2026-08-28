"use client";

import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";

export function OnboardingProgress({ step, total = 3 }: { step: number; total?: number }) {
  const dm = useDashboardMessages();

  return (
    <div className="mb-6">
      <div className="flex gap-1.5">
        {Array.from({ length: total }).map((_, i) => (
          <span
            key={i}
            className={`h-1.5 flex-1 rounded-full transition-colors ${
              i < step ? "bg-primary" : "bg-border"
            }`}
          />
        ))}
      </div>
      <p className="mt-2 text-xs font-medium uppercase tracking-wide text-ink-faint">
        {formatMessage(dm.auth.onboarding.stepOf, { step, total })}
      </p>
    </div>
  );
}
