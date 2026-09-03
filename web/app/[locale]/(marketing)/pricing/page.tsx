import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { PricingPlans } from "@/components/marketing/PricingPlans";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "pricing.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/pricing`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/pricing`,
      languages,
    },
    openGraph: {
      title: t("title"),
      description: t("description"),
      url: `${siteConfig.url}/${locale}/pricing`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI Pricing - free to get started, no credit card required",
        },
      ],
    },
  };
}

export default async function PricingPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "pricing" });

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Pricing", url: `${siteConfig.url}/${locale}/pricing` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container>
          <PricingPlans />
          <p className="mt-10 text-center text-sm text-ink-muted">
            {t("footerPrompt")}{" "}
            <Link href="/features" className="font-medium text-primary underline underline-offset-2">
              {t("footerFeatures")}
            </Link>
            {t("footerMiddle")}{" "}
            <Link href="/faq" className="font-medium text-primary underline underline-offset-2">
              {t("footerFaq")}
            </Link>{" "}
            {t("footerEnd")}
          </p>
        </Container>
      </section>
    </>
  );
}
