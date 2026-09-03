import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { Container } from "@/components/ui/Container";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "privacy.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/privacy`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/privacy`,
      languages,
    },
    openGraph: {
      title: `${t("title")} | CurecordAI`,
      description: t("description"),
      url: `${siteConfig.url}/${locale}/privacy`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI Privacy Policy",
        },
      ],
    },
  };
}

export default async function PrivacyPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "privacy" });
  const sections = t.raw("sections") as { title: string; body: string }[];

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Privacy Policy", url: `${siteConfig.url}/${locale}/privacy` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container className="max-w-3xl">
          <div className="flex flex-col gap-10">
            {sections.map((section) => (
              <div key={section.title}>
                <h2 className="text-2xl font-semibold text-ink">{section.title}</h2>
                <p className="mt-3 text-base leading-relaxed text-ink-muted">{section.body}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>
    </>
  );
}
