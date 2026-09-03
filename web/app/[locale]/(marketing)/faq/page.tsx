import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import FAQSchema from "@/components/seo/FAQSchema";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { FAQAccordion } from "@/components/marketing/FAQAccordion";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "faq.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/faq`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/faq`,
      languages,
    },
    openGraph: {
      title: t("title"),
      description: t("description"),
      url: `${siteConfig.url}/${locale}/faq`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI FAQ - frequently asked questions",
        },
      ],
    },
  };
}

export default async function FAQPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "faq" });
  const faqs = t.raw("items") as { question: string; answer: string }[];

  return (
    <>
      <FAQSchema faqs={faqs} />
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "FAQ", url: `${siteConfig.url}/${locale}/faq` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container className="max-w-3xl">
          <FAQAccordion faqs={faqs} />
          <p className="mt-10 text-center text-sm text-ink-muted">
            {t("footerPrompt")}{" "}
            <Link href="/features" className="font-medium text-primary underline underline-offset-2">
              {t("footerFeatures")}
            </Link>
            ,{" "}
            <Link href="/how-it-works" className="font-medium text-primary underline underline-offset-2">
              {t("footerHowItWorks")}
            </Link>
            ,{" "}
            <Link href="/pricing" className="font-medium text-primary underline underline-offset-2">
              {t("footerPricing")}
            </Link>
            .
          </p>
        </Container>
      </section>
    </>
  );
}
