import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { HeartStraight, ShieldCheck, Users } from "@phosphor-icons/react/dist/ssr";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { CTABanner } from "@/components/marketing/CTABanner";
import { Container } from "@/components/ui/Container";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "about.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/about`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/about`,
      languages,
    },
    openGraph: {
      title: `${t("title")} | CurecordAI`,
      description: t("description"),
      url: `${siteConfig.url}/${locale}/about`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "About CurecordAI - health records built for Pakistani families",
        },
      ],
    },
  };
}

// Icon + stable message key only; the copy comes from "about.values.*".
const values = [
  { key: "patients", icon: HeartStraight },
  { key: "privacy", icon: ShieldCheck },
  { key: "family", icon: Users },
] as const;

export default async function AboutPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "about" });

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "About", url: `${siteConfig.url}/${locale}/about` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">
              {t("missionHeading")}
            </h2>
            <p className="mt-4 text-lg text-ink-muted">{t("missionBody")}</p>
          </div>
          <div className="mt-14 grid gap-6 sm:grid-cols-3">
            {values.map((value) => (
              <div key={value.key} className="rounded-2xl border border-border p-6">
                <value.icon size={32} className="text-primary" weight="duotone" />
                <h3 className="mt-4 text-lg font-semibold text-ink">
                  {t(`values.${value.key}.title`)}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">
                  {t(`values.${value.key}.description`)}
                </p>
              </div>
            ))}
          </div>
        </Container>
      </section>
      <CTABanner title={t("ctaTitle")} description={t("ctaDescription")} />
    </>
  );
}
