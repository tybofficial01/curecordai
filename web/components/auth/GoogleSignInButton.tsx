"use client";

import { useEffect, useRef, useState } from "react";
import Script from "next/script";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/client";
import { loginGoogle } from "@/lib/api/auth";
import { useAuth } from "@/lib/auth/AuthContext";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: { credential: string }) => void;
          }) => void;
          renderButton: (parent: HTMLElement, options: Record<string, unknown>) => void;
        };
      };
    };
  }
}

export function GoogleSignInButton() {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const buttonRef = useRef<HTMLDivElement>(null);
  const [scriptLoaded, setScriptLoaded] = useState(false);
  const [error, setError] = useState("");
  const dm = useDashboardMessages();
  const clientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;

  useEffect(() => {
    if (!scriptLoaded || !clientId || !window.google || !buttonRef.current) return;

    window.google.accounts.id.initialize({
      client_id: clientId,
      callback: async (response) => {
        setError("");
        try {
          const result = await loginGoogle(response.credential);
          applySession(result);
          await refreshUser();
          router.push(result.is_new_user ? "/auth/onboarding/step1" : "/dashboard");
        } catch (err) {
          setError(err instanceof ApiError ? err.message : dm.auth.errors.googleFailed);
        }
      },
    });

    // Google's button is a fixed-width iframe (no CSS max-width support), so its pixel width
    // has to be measured from the actual container - a hardcoded value overflows the auth card
    // on narrow phones (< ~376px viewports) and clips or forces horizontal scroll.
    window.google.accounts.id.renderButton(buttonRef.current, {
      theme: "outline",
      size: "large",
      shape: "pill",
      logo_alignment: "left",
      width: Math.round(buttonRef.current.getBoundingClientRect().width),
      text: "continue_with",
    });
  }, [scriptLoaded, clientId, applySession, refreshUser, router, dm]);

  if (!clientId) return null;

  return (
    <div className="flex flex-col items-center gap-2">
      <Script
        src="https://accounts.google.com/gsi/client"
        strategy="afterInteractive"
        onReady={() => setScriptLoaded(true)}
      />
      {/* Fixed height matches the rendered Google iframe (size="large") so the layout doesn't
          jump once the script loads and the button swaps in; overflow-hidden keeps the iframe's
          own corners from poking past our rounded-full frame. */}
      <div ref={buttonRef} className="h-11 w-full overflow-hidden rounded-full" />
      {error && <p className="text-sm font-medium text-error">{error}</p>}
    </div>
  );
}
