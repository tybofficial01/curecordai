"use client";

import Image from "next/image";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

/**
 * Shown in place of the sign-in/sign-up form while AuthProvider is silently
 * checking for an existing session. Without this, an already-authenticated
 * user briefly sees the auth form flash before the redirect to /dashboard.
 */
export function AuthLoader() {
  const dm = useDashboardMessages();

  return (
    <div className="flex flex-col items-center justify-center gap-4 py-12" role="status" aria-label={dm.common.checkingSession}>
      <Image src="/logo.png" alt="CurecordAI" width={56} height={56} className="rounded-xl" priority />
      <p className="text-lg font-bold text-primary">CurecordAI</p>
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-border border-t-primary" />
    </div>
  );
}
