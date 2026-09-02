"use server";

import { cookies } from "next/headers";
import type { AppLocale } from "@/i18n/routing";
import { APP_LOCALE_COOKIE } from "@/i18n/appLocale";

// ~13 months, matching next-intl's own default locale-cookie lifetime.
const MAX_AGE_SECONDS = 60 * 60 * 24 * 400;

export async function setAppLocaleAction(locale: AppLocale): Promise<void> {
  const store = await cookies();
  store.set(APP_LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: MAX_AGE_SECONDS,
    sameSite: "lax",
  });
}
