"use client";

import { useCallback, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useLocale as useNextIntlLocale } from "next-intl";
import type { AppLocale } from "@/i18n/routing";
import type { AppLanguage } from "@/i18n/language";
import { apiLanguageToLocale, localeToApiLanguage, localeToDir, localeToHtmlLang } from "@/i18n/language";
import { setAppLocaleAction } from "@/i18n/setAppLocale";

/**
 * Dashboard/auth-side language switch. The current locale comes from
 * next-intl's own useLocale() (fed by AppLocaleProvider, which resolves it
 * from the NEXT_LOCALE_APP cookie server-side - see i18n/appLocale.ts), so
 * this is a thin wrapper rather than a second locale store: it just maps
 * next-intl's URL-style locale id ("en" | "ur" | "roman-ur") to and from the
 * canonical backend/API preference value ("en" | "ur" | "roman_ur" -
 * FullProfile.language) that the rest of the app - and useSyncThemeWithAccount,
 * which persists it to the account - already works with.
 */
export type DashboardLanguage = AppLanguage;

export function useLocale() {
  const nextIntlLocale = useNextIntlLocale() as AppLocale;
  const language: DashboardLanguage = localeToApiLanguage[nextIntlLocale] ?? "en";
  const router = useRouter();
  const [, startTransition] = useTransition();

  const setLanguage = useCallback(
    (next: DashboardLanguage) => {
      const locale = apiLanguageToLocale[next];
      // Apply lang/dir instantly so RTL/LTR doesn't wait on the server round
      // trip below - AppLocaleHtmlSync corrects these again on next SSR too.
      document.documentElement.setAttribute("lang", localeToHtmlLang[locale]);
      document.documentElement.setAttribute("dir", localeToDir[locale]);
      document.documentElement.setAttribute("data-locale", locale);
      startTransition(async () => {
        await setAppLocaleAction(locale);
        router.refresh();
      });
    },
    [router]
  );

  return { language, setLanguage };
}
