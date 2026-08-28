import type { Metadata } from "next";
import Link from "next/link";
import { AuthProvider } from "@/lib/auth/AuthContext";
import { AppLocaleProvider } from "@/components/providers/AppLocaleProvider";

// Applies to every route under /auth/* (signin, signup, forgot-password, and any future
// auth route) - these are utility forms with no search intent of their own, so none of
// them should be indexed. Individual page.tsx files under this layout don't set their own
// `robots`, so this value is inherited as-is rather than overridden.
export const metadata: Metadata = {
  robots: {
    index: false,
    follow: false,
  },
};

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppLocaleProvider>
      <AuthProvider>
        <div className="flex min-h-screen flex-col items-center justify-center bg-surface px-4 py-10 sm:px-6 sm:py-12">
          <Link href="/" className="mb-6 text-xl font-bold text-primary sm:mb-8 sm:text-2xl">
            CurecordAI
          </Link>
          <div className="w-full max-w-md rounded-2xl border border-border bg-card p-5 shadow-sm sm:p-8">
            {children}
          </div>
        </div>
      </AuthProvider>
    </AppLocaleProvider>
  );
}
