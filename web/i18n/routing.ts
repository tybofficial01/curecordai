import { defineRouting } from "next-intl/routing";

// URL-facing locale ids for the marketing site only (see i18n/language.ts for
// the mapping to the backend's persisted `en` | `ur` | `roman_ur` preference
// value, which uses an underscore and is a separate concern from routing).
export const routing = defineRouting({
  locales: ["en", "ur", "roman-ur"],
  defaultLocale: "en",
  // Every locale - including the default - gets a URL prefix ("/en/...",
  // "/ur/...", "/roman-ur/...") so hreflang/canonical tags are unambiguous
  // and a bare "/" always redirects to an explicit locale.
  localePrefix: "always",
});

export type AppLocale = (typeof routing.locales)[number];
