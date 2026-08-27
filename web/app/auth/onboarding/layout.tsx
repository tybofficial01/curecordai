"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth/AuthContext";
import { OnboardingProvider, PENDING_NAME_KEY } from "@/lib/onboarding/OnboardingContext";

export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  const { isSignedIn, isLoading } = useAuth();
  const router = useRouter();
  const [initialFullName] = useState(() => {
    if (typeof window === "undefined") return "";
    const name = window.sessionStorage.getItem(PENDING_NAME_KEY) ?? "";
    window.sessionStorage.removeItem(PENDING_NAME_KEY);
    return name;
  });

  useEffect(() => {
    if (!isLoading && !isSignedIn) router.replace("/auth/signup");
  }, [isLoading, isSignedIn, router]);

  if (isLoading || !isSignedIn) return null;

  return <OnboardingProvider initialFullName={initialFullName}>{children}</OnboardingProvider>;
}
