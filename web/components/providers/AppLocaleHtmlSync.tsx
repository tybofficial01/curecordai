"use client";

import { useEffect } from "react";
import type { AppLocale } from "@/i18n/routing";

/**
 * Dashboard/auth counterpart of components/marketing/LocaleHtmlSync.tsx -
 * same mechanics (inline pre-hydration script + client effect correcting
 * html[lang]/[dir]), driven by the cookie-resolved AppLocale (i18n/appLocale.ts)
 * instead of a URL locale segment, since this side of the app has none.
 */
export function AppLocaleHtmlSync({ locale, lang, dir }: { locale: AppLocale; lang: string; dir: "ltr" | "rtl" }) {
  useEffect(() => {
    document.documentElement.setAttribute("lang", lang);
    document.documentElement.setAttribute("dir", dir);
    document.documentElement.setAttribute("data-locale", locale);
  }, [locale, lang, dir]);

  const initScript = `(function(){try{document.documentElement.setAttribute("lang",${JSON.stringify(
    lang
  )});document.documentElement.setAttribute("dir",${JSON.stringify(dir)});document.documentElement.setAttribute("data-locale",${JSON.stringify(
    locale
  )});}catch(e){}})();`;

  return <script dangerouslySetInnerHTML={{ __html: initScript }} />;
}
