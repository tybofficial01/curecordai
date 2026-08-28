"use client";

import { useEffect, useState } from "react";
import Script from "next/script";
import { useRouter } from "next/navigation";
import { AppleLogo } from "@phosphor-icons/react/dist/ssr";
import { ApiError } from "@/lib/api/client";
import { loginApple } from "@/lib/api/auth";
import { useAuth } from "@/lib/auth/AuthContext";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

declare global {
  interface Window {
    AppleID?: {
      auth: {
        init: (config: {
          clientId: string;
          scope: string;
          redirectURI: string;
          usePopup: boolean;
        }) => void;
        signIn: () => Promise<{
          authorization: { id_token: string };
          user?: { name?: { firstName?: string; lastName?: string } };
        }>;
      };
    };
  }
}

// Renders nothing unless NEXT_PUBLIC_APPLE_CLIENT_ID is configured - Apple Sign In requires a
// registered Services ID + redirect URI in the Apple Developer portal, which isn't set up yet.
export function AppleSignInButton() {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const [scriptLoaded, setScriptLoaded] = useState(false);
  const [error, setError] = useState("");
  const dm = useDashboardMessages();
  const clientId = process.env.NEXT_PUBLIC_APPLE_CLIENT_ID;
  const redirectUri = process.env.NEXT_PUBLIC_APPLE_REDIRECT_URI;

  useEffect(() => {
    if (!scriptLoaded || !clientId || !redirectUri || !window.AppleID) return;
    window.AppleID.auth.init({
      clientId,
      scope: "name email",
      redirectURI: redirectUri,
      usePopup: true,
    });
  }, [scriptLoaded, clientId, redirectUri]);

  async function handleSignIn() {
    setError("");
    try {
      const response = await window.AppleID?.auth.signIn();
      if (!response) return;
      const fullName = response.user?.name
        ? `${response.user.name.firstName ?? ""} ${response.user.name.lastName ?? ""}`.trim()
        : undefined;
      const result = await loginApple(response.authorization.id_token, fullName);
      applySession(result);
      await refreshUser();
      router.push(result.is_new_user ? "/auth/onboarding/step1" : "/dashboard");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.appleFailed);
    }
  }

  if (!clientId || !redirectUri) return null;

  return (
    <div className="flex flex-col items-center gap-2">
      <Script
        src="https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"
        strategy="afterInteractive"
        onLoad={() => setScriptLoaded(true)}
      />
      <button
        type="button"
        onClick={handleSignIn}
        className="flex h-11 w-full items-center justify-center gap-2 rounded-full border border-border text-sm font-medium text-ink transition-colors hover:bg-surface"
      >
        <AppleLogo size={18} weight="fill" />
        {dm.auth.continueWithApple}
      </button>
      {error && <p className="text-sm font-medium text-error">{error}</p>}
    </div>
  );
}
