import { NextIntlClientProvider } from "next-intl";
import type { AppLocale } from "@/i18n/routing";
import { getAppLocale } from "@/i18n/appLocale";
import { localeToDir, localeToHtmlLang } from "@/i18n/language";
import { AppLocaleHtmlSync } from "@/components/providers/AppLocaleHtmlSync";
import enMessages from "@/messages/en.json";
import urMessages from "@/messages/ur.json";
import romanUrMessages from "@/messages/roman-ur.json";

// Same per-locale JSON files the marketing site loads (web/messages/*.json),
// scoped to the "app" namespace - the dashboard/auth message catalog that used
// to live in lib/locale/messages/*.ts (see lib/locale/dashboardMessages.ts).
// One translation-key space, one loading mechanism, shared with the marketing
// site; the only real difference is locale *source* (cookie here, URL there),
// which is inherent to this side of the app having no locale route segment.
const appMessagesByLocale: Record<AppLocale, (typeof enMessages)["app"]> = {
  en: enMessages.app,
  ur: urMessages.app,
  "roman-ur": romanUrMessages.app,
};

/**
 * Wraps /dashboard and /auth with next-intl, resolving locale from the
 * NEXT_LOCALE_APP cookie (set by the in-app language switcher via
 * lib/locale/useLocale.ts -> i18n/setAppLocale.ts) instead of a URL segment,
 * so this SSRs with the right language/direction from first paint - no more
 * flash of English while the client mounts and re-applies a saved preference.
 */
export async function AppLocaleProvider({ children }: { children: React.ReactNode }) {
  const locale = await getAppLocale();
  const messages = appMessagesByLocale[locale];

  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      <AppLocaleHtmlSync locale={locale} lang={localeToHtmlLang[locale]} dir={localeToDir[locale]} />
      {children}
    </NextIntlClientProvider>
  );
}
