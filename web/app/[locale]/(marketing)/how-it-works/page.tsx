import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { HowItWorksSteps } from "@/components/marketing/HowItWorksSteps";
import { CTABanner } from "@/components/marketing/CTABanner";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "howItWorks.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/how-it-works`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/how-it-works`,
      languages,
    },
    openGraph: {
      title: t("title"),
      description: t("description"),
      url: `${siteConfig.url}/${locale}/how-it-works`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "How CurecordAI works - upload, ask, and share your medical records",
        },
      ],
    },
  };
}

// Stable message keys for the three family scenarios ("howItWorks.scenarios.*").
const scenarioKeys = ["parent", "specialist", "report"] as const;

export default async function HowItWorksPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "howItWorks" });

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "How It Works", url: `${siteConfig.url}/${locale}/how-it-works` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container>
          <h2 className="text-center text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            {t("stepsHeading")}
          </h2>
          <div className="mt-12">
            <HowItWorksSteps />
          </div>
        </Container>
      </section>

      <section className="bg-surface py-16 sm:py-20">
        <Container>
          <div className="mx-auto max-w-3xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">
              {t("familyHeading")}
            </h2>
            <p className="mt-4 text-lg text-ink-muted">
              {t("familyBody")}{" "}
              <Link href="/features" className="font-medium text-primary underline underline-offset-2">
                {t("familyLink")}
              </Link>
              .
            </p>
          </div>
          <div className="mt-14 grid gap-6 sm:grid-cols-3">
            {scenarioKeys.map((key) => (
              <div key={key} className="rounded-2xl border border-border p-6">
                <h3 className="text-lg font-semibold text-ink">{t(`scenarios.${key}.title`)}</h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">
                  {t(`scenarios.${key}.description`)}
                </p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      <CTABanner />
    </>
  );
}
