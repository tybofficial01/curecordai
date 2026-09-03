import { useMessages } from "next-intl";
import enMessages from "@/messages/en.json";

// Derived from the English JSON (web/messages/en.json's "app" namespace) so
// adding a key there immediately fails typecheck on ur.json/roman-ur.json
// until they're translated too (see scripts/check-translations, run in CI) -
// same safety net the old lib/locale/messages/en.ts source-of-truth had,
// just anchored to the JSON that's now the single loading mechanism shared
// with the marketing site instead of a parallel TS object.
export type DashboardMessages = (typeof enMessages)["app"];

/**
 * Dashboard/auth message catalog for the current locale. AppLocaleProvider
 * (components/providers/AppLocaleProvider.tsx) scopes the nearest
 * NextIntlClientProvider's `messages` to exactly this "app" namespace, so
 * useMessages() here returns the same shape as DashboardMessages - no lookup
 * keyed by language needed anymore, next-intl already resolved it server-side.
 */
export function useDashboardMessages(): DashboardMessages {
  return useMessages() as unknown as DashboardMessages;
}

/**
 * Weekday names in the backend's own `days_of_week` order (0 = Monday .. 6 =
 * Sunday), so a stored index can be used directly as an array index. Lives here
 * rather than in a page module because Next.js forbids non-route exports from
 * `app/**\/page.tsx`, and both the medications list and the add form need it.
 */
export function dayLabels(messages: DashboardMessages): string[] {
  const d = messages.medications.days;
  return [d.mon, d.tue, d.wed, d.thu, d.fri, d.sat, d.sun];
}

/**
 * Fills `{name}`-style placeholders in a catalog string. Deliberately tiny -
 * these messages only ever need positional substitution, and next-intl's
 * useTranslations()/ICU formatting isn't a good fit for this file's plain
 * nested-object access pattern (dm.some.key rather than t('some.key')).
 *
 * Unknown placeholders are left untouched rather than blanked, so a typo shows
 * up as a visible `{typo}` in the UI instead of silently disappearing.
 */
export function formatMessage(template: string, values: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) => (key in values ? String(values[key]) : match));
}
