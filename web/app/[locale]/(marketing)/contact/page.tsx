import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { EnvelopeSimple } from "@phosphor-icons/react/dist/ssr";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { ContactForm } from "@/components/marketing/ContactForm";
import { Container } from "@/components/ui/Container";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "contact.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/contact`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/contact`,
      languages,
    },
    openGraph: {
      title: `${t("title")} | CurecordAI`,
      description: t("description"),
      url: `${siteConfig.url}/${locale}/contact`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "Contact the CurecordAI team",
        },
      ],
    },
  };
}

export default async function ContactPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "contact" });

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Contact", url: `${siteConfig.url}/${locale}/contact` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container className="grid gap-12 lg:grid-cols-2">
          <div>
            <h2 className="text-2xl font-semibold text-ink">{t("formHeading")}</h2>
            <div className="mt-6">
              <ContactForm />
            </div>
          </div>
          <div>
            <h2 className="text-2xl font-semibold text-ink">{t("otherHeading")}</h2>
            <a
              href={`mailto:${siteConfig.supportEmail}`}
              className="mt-6 flex items-center gap-3 text-ink-muted transition-colors hover:text-primary"
            >
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary">
                <EnvelopeSimple size={20} />
              </span>
              <span className="text-sm font-medium">{siteConfig.supportEmail}</span>
            </a>
          </div>
        </Container>
      </section>
    </>
  );
}
