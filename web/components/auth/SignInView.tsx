"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AuthMethodTabs } from "@/components/auth/AuthMethodTabs";
import { EmailSignInForm } from "@/components/auth/EmailAuthForm";
import { PhoneAuthForm } from "@/components/auth/PhoneAuthForm";
import { GoogleSignInButton } from "@/components/auth/GoogleSignInButton";
import { AppleSignInButton } from "@/components/auth/AppleSignInButton";
import { AuthLoader } from "@/components/auth/AuthLoader";
import { useAuth } from "@/lib/auth/AuthContext";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

export function SignInView() {
  const { isLoading, isSignedIn } = useAuth();
  const router = useRouter();
  const dm = useDashboardMessages();

  useEffect(() => {
    if (!isLoading && isSignedIn) router.replace("/dashboard");
  }, [isLoading, isSignedIn, router]);

  if (isLoading || isSignedIn) {
    return <AuthLoader />;
  }

  return (
    <>
      <h1 className="text-2xl font-bold text-ink">{dm.auth.signInTitle}</h1>
      <p className="mt-1 text-sm text-ink-muted">{dm.auth.signInSubtitle}</p>

      <div className="mt-6">
        <AuthMethodTabs
          email={<EmailSignInForm />}
          phone={<PhoneAuthForm mode="signin" />}
        />
      </div>

      <div className="my-6 flex items-center gap-3">
        <span className="h-px flex-1 bg-border" />
        <span className="text-xs font-medium uppercase text-ink-faint">{dm.auth.orContinueWith}</span>
        <span className="h-px flex-1 bg-border" />
      </div>

      <div className="flex flex-col gap-3">
        <GoogleSignInButton />
        <AppleSignInButton />
      </div>

      <p className="mt-8 text-center text-sm text-ink-muted">
        {dm.auth.noAccount}{" "}
        <Link href="/auth/signup" className="font-medium text-primary hover:underline">
          {dm.auth.getStarted}
        </Link>
      </p>
    </>
  );
}
