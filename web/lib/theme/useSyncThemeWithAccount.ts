"use client";

import { useEffect, useRef } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { useTheme } from "@/lib/useTheme";
import { useLocale } from "@/lib/locale/useLocale";
import { getProfile, updatePreferences } from "@/lib/api/profile";
import type { AppLanguage } from "@/i18n/language";

function toAppLanguage(value: string): AppLanguage {
  return value === "ur" ? "ur" : value === "roman_ur" ? "roman_ur" : "en";
}

/**
 * Keeps html[data-theme] (owned by useTheme(), toggled from the marketing Navbar and the
 * dashboard sidebar/header) and the dashboard/auth locale (owned by useLocale(), backed by
 * next-intl + the NEXT_LOCALE_APP cookie - see i18n/appLocale.ts, toggled from the
 * dashboard Profile & Settings page) in sync with the signed-in user's saved preferences in
 * FullProfile.theme / FullProfile.language - the same backend fields the Flutter app reads
 * and writes via PUT /profile/preferences. Mount once, anywhere inside AuthProvider; renders
 * nothing.
 *
 * Both preferences live on the same backend row and are set together via a single
 * PUT /profile/preferences call, so this hook owns both rather than duplicating the
 * profile-fetch round trip across two separate hooks.
 */
export function useSyncThemeWithAccount() {
  const { isSignedIn, getAccessToken } = useAuth();
  const { theme, setTheme } = useTheme();
  const { language, setLanguage } = useLocale();
  const appliedFromAccountRef = useRef(false);
  // Set right before we programmatically apply the account's theme/language, so the effect
  // below doesn't immediately fetch-and-PUT the exact value we just fetched back to the server.
  const skipNextPersistRef = useRef(false);

  // On sign-in, the account's saved theme/language become authoritative - overriding whatever
  // useTheme()/useLocale() had already guessed from localStorage / prefers-color-scheme /
  // navigator.language pre-login.
  useEffect(() => {
    if (!isSignedIn) {
      appliedFromAccountRef.current = false;
      return;
    }
    let cancelled = false;
    (async () => {
      const token = await getAccessToken();
      if (!token || cancelled) return;
      try {
        const profile = await getProfile(token);
        if (cancelled) return;
        const accountTheme = profile.theme === "dark" ? "dark" : "light";
        const accountLanguage = toAppLanguage(profile.language);
        appliedFromAccountRef.current = true;
        if (accountTheme !== theme || accountLanguage !== language) {
          skipNextPersistRef.current = true;
          if (accountTheme !== theme) setTheme(accountTheme);
          if (accountLanguage !== language) setLanguage(accountLanguage);
        }
      } catch {
        // Keep whatever theme/language is already applied - non-critical.
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSignedIn, getAccessToken]);

  // Push subsequent toggles - theme from either the dashboard or the marketing Navbar (both
  // share html[data-theme]), language from the Profile & Settings page - back to the account
  // so preferences follow the user across devices, including the Flutter app.
  useEffect(() => {
    if (!isSignedIn || !appliedFromAccountRef.current) return;
    if (skipNextPersistRef.current) {
      skipNextPersistRef.current = false;
      return;
    }
    let cancelled = false;
    (async () => {
      const token = await getAccessToken();
      if (!token || cancelled) return;
      try {
        // theme and language both live in shared DOM-backed state (useTheme()/useLocale()),
        // so the values read here are already current - no need to refetch the profile first.
        await updatePreferences(token, { language, is_dark_theme: theme === "dark" });
      } catch {
        // Non-critical - the user's next explicit toggle or preferences save will retry.
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [theme, language, isSignedIn]);
}

// Re-exported under its own name too, since the language half of this sync is the piece other
// call sites (e.g. a future locale-only consumer) are more likely to reach for by name - both
// names point at the same hook so the profile-fetch round trip is never duplicated.
export const useSyncLocaleWithAccount = useSyncThemeWithAccount;
