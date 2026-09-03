import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import SoftwareAppSchema from "@/components/seo/SoftwareAppSchema";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import FAQSchema from "@/components/seo/FAQSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { FeaturesGrid } from "@/components/marketing/FeaturesGrid";
import { FAQAccordion } from "@/components/marketing/FAQAccordion";
import { CTABanner } from "@/components/marketing/CTABanner";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "features.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/features`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/features`,
      languages,
    },
    openGraph: {
      title: `CurecordAI - ${t("title")}`,
      description: t("description"),
      url: `${siteConfig.url}/${locale}/features`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI Features - AI medical summary, health assistant, family vault, and doctor sharing",
        },
      ],
    },
  };
}

export default async function FeaturesPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "features" });
  const featuresFaqs = t.raw("faqs") as { question: string; answer: string }[];

  return (
    <>
      <SoftwareAppSchema />
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Features", url: `${siteConfig.url}/${locale}/features` },
        ]}
      />
      <FAQSchema faqs={featuresFaqs} />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container>
          <FeaturesGrid />
          <p className="mt-10 text-center text-sm text-ink-muted">
            {t("footerPrompt")}{" "}
            <Link href="/how-it-works" className="font-medium text-primary underline underline-offset-2">
              {t("footerHowItWorks")}
            </Link>{" "}
            {t("footerOr")}{" "}
            <Link href="/pricing" className="font-medium text-primary underline underline-offset-2">
              {t("footerPricing")}
            </Link>
            .
          </p>
        </Container>
      </section>
      <section className="bg-surface py-16 sm:py-20">
        <Container className="max-w-3xl">
          <h2 className="text-center text-3xl font-bold tracking-tight text-ink sm:text-4xl">
            {t("faqHeading")}
          </h2>
          <div className="mt-10">
            <FAQAccordion faqs={featuresFaqs} />
          </div>
        </Container>
      </section>
      <CTABanner />
    </>
  );
}
