import { cookies } from "next/headers";
import { hasLocale } from "next-intl";
import { routing, type AppLocale } from "@/i18n/routing";

// Locale source for the dashboard/auth side of the app, which deliberately has
// no URL locale segment (see i18n/routing.ts's comment and middleware.ts's
// matcher). The in-app language switcher (lib/locale/useLocale.ts) persists
// the chosen locale here via setAppLocaleAction, so every subsequent
// server-rendered request - not just the client that switched it - already
// knows the right locale/messages before first paint.
export const APP_LOCALE_COOKIE = "NEXT_LOCALE_APP";

export async function getAppLocale(): Promise<AppLocale> {
  const store = await cookies();
  const value = store.get(APP_LOCALE_COOKIE)?.value;
  return hasLocale(routing.locales, value) ? value : routing.defaultLocale;
}
