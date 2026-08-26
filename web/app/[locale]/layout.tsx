import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { hasLocale, NextIntlClientProvider } from "next-intl";
import { routing, type AppLocale } from "@/i18n/routing";
import { localeToDir, localeToHtmlLang } from "@/i18n/language";
import { LocaleHtmlSync } from "@/components/marketing/LocaleHtmlSync";
import { siteConfig } from "@/content/site";

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

type Props = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

// Shared metadata that every marketing page inherits (per-page metadata,
// e.g. app/[locale]/(marketing)/page.tsx and faq/page.tsx, layer their own
// title/description/alternates.languages on top of this via generateMetadata).
export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) return {};
  return {
    metadataBase: new URL(siteConfig.url),
  };
}

export default async function LocaleLayout({ children, params }: Props) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }
  const typedLocale = locale as AppLocale;

  return (
    <NextIntlClientProvider locale={typedLocale}>
      {/*
        Next.js only allows a single <html> to be rendered for the whole app,
        and it's already owned by the true root layout (app/layout.tsx) so
        that the un-prefixed /dashboard and /auth routes - which stay
        outside this [locale] segment - keep working exactly as before.
        LocaleHtmlSync reconciles document.documentElement's lang/dir with
        this route's locale instead, mirroring the existing
        html[data-theme] pattern (lib/useTheme.ts): an inline pre-hydration
        script avoids a flash of the wrong direction/language, and a client
        effect keeps it correct across client-side navigations between
        locales.
      */}
      <LocaleHtmlSync locale={typedLocale} lang={localeToHtmlLang[typedLocale]} dir={localeToDir[typedLocale]} />
      {children}
    </NextIntlClientProvider>
  );
}
