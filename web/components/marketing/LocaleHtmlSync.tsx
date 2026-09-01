"use client";

import { useEffect } from "react";
import type { AppLocale } from "@/i18n/routing";

/**
 * Keeps the root <html> element's lang/dir attributes in sync with the
 * current marketing-site locale segment (/en, /ur, /roman-ur).
 *
 * The single <html> tag lives in the true root layout (app/layout.tsx),
 * shared with the un-prefixed /dashboard and /auth routes, so this
 * component can't render its own <html> - instead it mirrors the existing
 * html[data-theme] pattern (lib/useTheme.ts): an inline script placed
 * before this component's own render point corrects the attributes as
 * early as possible to avoid a flash of the wrong language/direction, and
 * a client-side effect keeps them correct across client-side navigation
 * between locales (e.g. clicking the language switcher).
 */
export function LocaleHtmlSync({ locale, lang, dir }: { locale: AppLocale; lang: string; dir: "ltr" | "rtl" }) {
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
