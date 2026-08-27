"use client";

import { useState, type ReactNode } from "react";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

export function AuthMethodTabs({ email, phone }: { email: ReactNode; phone: ReactNode }) {
  const [method, setMethod] = useState<"email" | "phone">("email");
  const dm = useDashboardMessages();

  return (
    <div>
      <div className="mb-6 grid grid-cols-2 gap-1 rounded-full bg-surface p-1">
        <button
          type="button"
          onClick={() => setMethod("email")}
          className={`rounded-full py-2 text-sm font-semibold transition-colors ${
            method === "email" ? "bg-card text-primary shadow-sm" : "text-ink-muted"
          }`}
        >
          {dm.auth.emailTab}
        </button>
        <button
          type="button"
          onClick={() => setMethod("phone")}
          className={`rounded-full py-2 text-sm font-semibold transition-colors ${
            method === "phone" ? "bg-card text-primary shadow-sm" : "text-ink-muted"
          }`}
        >
          {dm.auth.phoneTab}
        </button>
      </div>
      {method === "email" ? email : phone}
    </div>
  );
}
