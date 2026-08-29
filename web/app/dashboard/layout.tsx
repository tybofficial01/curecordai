import type { Metadata } from "next";
import { AuthProvider } from "@/lib/auth/AuthContext";
import { ActiveProfileProvider } from "@/lib/family/ActiveProfileContext";
import { DashboardShell } from "@/components/dashboard/DashboardShell";
import { ThemeAccountSync } from "@/components/dashboard/ThemeAccountSync";
import { AppLocaleProvider } from "@/components/providers/AppLocaleProvider";

export const metadata: Metadata = {
  robots: {
    index: false,
    follow: false,
    noarchive: true,
    nosnippet: true,
  },
};

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppLocaleProvider>
      <AuthProvider>
        <ThemeAccountSync />
        <ActiveProfileProvider>
          <DashboardShell>{children}</DashboardShell>
        </ActiveProfileProvider>
      </AuthProvider>
    </AppLocaleProvider>
  );
}
