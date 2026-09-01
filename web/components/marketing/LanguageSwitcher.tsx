"use client";

import { useState } from "react";
import { useLocale } from "next-intl";
import { Translate, Check } from "@phosphor-icons/react/dist/ssr";
import { usePathname, useRouter } from "@/i18n/navigation";
import { routing, type AppLocale } from "@/i18n/routing";
import { localeLabels } from "@/i18n/language";

/**
 * Compact language switcher for the marketing navbar - matches the glass
 * pill treatment used by the rest of the navbar (see .glass-navbar-item in
 * globals.css and ThemeToggle for the same visual language) rather than
 * introducing a new UI style. Navigates between /en, /ur, /roman-ur while
 * preserving the current page path via next-intl's locale-aware router.
 */
export function LanguageSwitcher() {
  const [open, setOpen] = useState(false);
  const locale = useLocale() as AppLocale;
  const pathname = usePathname();
  const router = useRouter();

  function selectLocale(next: AppLocale) {
    setOpen(false);
    if (next === locale) return;
    router.replace(pathname, { locale: next });
  }

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-label="Change language"
        aria-expanded={open}
        className="glass-navbar-item flex items-center gap-1.5 rounded-full px-3 py-2 text-sm font-medium text-[rgb(var(--navbar-fg-rgb)/0.65)] hover:text-[rgb(var(--navbar-fg-rgb))]"
      >
        <Translate size={18} weight="regular" />
        <span>{localeLabels[locale]}</span>
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="glass-navbar absolute end-0 top-full z-50 mt-2 flex min-w-[9rem] flex-col gap-0.5 rounded-2xl p-1.5">
            {routing.locales.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => selectLocale(option)}
                className={`flex items-center justify-between gap-2 rounded-xl px-3 py-2 text-start text-sm font-medium ${
                  option === locale
                    ? "text-[rgb(var(--navbar-fg-rgb))]"
                    : "text-[rgb(var(--navbar-fg-rgb)/0.65)] hover:text-[rgb(var(--navbar-fg-rgb))]"
                }`}
              >
                {localeLabels[option]}
                {option === locale && <Check size={14} weight="bold" />}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
