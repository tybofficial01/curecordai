import type { AppLocale } from "@/i18n/routing";
import type { AppLanguage } from "@/lib/api/types";

// Canonical backend/API preference value (FullProfile.language, PATCH
// /profile/preferences body) - underscore, not hyphen, and shared verbatim
// with the Flutter app. Defined in lib/api/types.ts (which mirrors backend
// schemas); re-exported here since this module is the natural place other
// locale-aware code already imports from. Kept distinct from the URL locale
// segment below, which is a routing-only concern for next-intl.
export type { AppLanguage };

export const localeToApiLanguage: Record<AppLocale, AppLanguage> = {
  en: "en",
  ur: "ur",
  "roman-ur": "roman_ur",
};

export const apiLanguageToLocale: Record<AppLanguage, AppLocale> = {
  en: "en",
  ur: "ur",
  roman_ur: "roman-ur",
};

// <html lang> / <html dir> per locale - Roman Urdu is Urdu transliterated
// into the Latin script, so it gets the "ur-Latn" BCP-47 tag and stays
// left-to-right like English, unlike Urdu script which is RTL.
export const localeToHtmlLang: Record<AppLocale, string> = {
  en: "en",
  ur: "ur",
  "roman-ur": "ur-Latn",
};

export const localeToDir: Record<AppLocale, "ltr" | "rtl"> = {
  en: "ltr",
  ur: "rtl",
  "roman-ur": "ltr",
};

export const localeLabels: Record<AppLocale, string> = {
  en: "EN",
  ur: "اردو",
  "roman-ur": "Roman Urdu",
};
