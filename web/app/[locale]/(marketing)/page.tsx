import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import SoftwareAppSchema from "@/components/seo/SoftwareAppSchema";
import { HeroFeaturesPhone } from "@/components/marketing/home/HeroFeaturesPhone";
import { ProblemSection } from "@/components/marketing/home/ProblemSection";
import { SolutionSection } from "@/components/marketing/home/SolutionSection";
import { StickyFeatureShowcase } from "@/components/marketing/StickyFeatureShowcase";
import { HowItWorksSteps } from "@/components/marketing/HowItWorksSteps";
import { PlatformsSection } from "@/components/marketing/PlatformsSection";
import { PricingPlans } from "@/components/marketing/PricingPlans";
import { FAQAccordion } from "@/components/marketing/FAQAccordion";
import { CTABanner } from "@/components/marketing/CTABanner";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "home.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}`,
      languages,
    },
    openGraph: {
      title: `CurecordAI - ${t("title")}`,
      description: t("description"),
      url: `${siteConfig.url}/${locale}`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI - AI powered health records for families",
        },
      ],
    },
  };
}

// Indices into faq.items (messages/{locale}.json) picked for the homepage
// teaser - kept as positions rather than matching on English question text
// so the same three questions are pulled regardless of locale.
const HOMEPAGE_FAQ_INDICES = [0, 1, 8];

export default async function HomePage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "home" });
  const faqT = await getTranslations({ locale, namespace: "faq" });
  const allFaqItems = faqT.raw("items") as { question: string; answer: string }[];
  const homepageFaqs = HOMEPAGE_FAQ_INDICES.map((i) => allFaqItems[i]).filter(Boolean);

  return (
    <>
      <SoftwareAppSchema />
      <HeroFeaturesPhone />
      <ProblemSection />
      <SolutionSection />

      <section
        id="features"
        className="scroll-mt-20 bg-gradient-to-b from-background to-[var(--showcase-bg)] py-16 sm:py-20"
      >
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{t("featuresHeading")}</h2>
            <p className="mt-3 text-lg text-ink-muted">
              {t("featuresBody")}{" "}
              <Link href="/features" className="font-medium text-primary underline underline-offset-2">
                {t("featuresLink")}
              </Link>
              .
            </p>
          </div>
        </Container>
      </section>

      <StickyFeatureShowcase />

      <section id="how-it-works" className="scroll-mt-20 bg-surface py-16 sm:py-20">
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{t("howItWorksHeading")}</h2>
            <p className="mt-3 text-lg text-ink-muted">
              {t("howItWorksBody")}{" "}
              <Link href="/how-it-works" className="font-medium text-primary underline underline-offset-2">
                {t("howItWorksLink")}
              </Link>
              .
            </p>
          </div>
          <div className="mt-14">
            <HowItWorksSteps />
          </div>
        </Container>
      </section>

      <PlatformsSection />

      <section id="pricing" className="scroll-mt-20 bg-surface py-16 sm:py-20">
        <Container>
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{t("pricingHeading")}</h2>
            <p className="mt-3 text-lg text-ink-muted">
              {t("pricingBody")}{" "}
              <Link href="/pricing" className="font-medium text-primary underline underline-offset-2">
                {t("pricingLink")}
              </Link>
              .
            </p>
          </div>
          <div className="mt-14">
            <PricingPlans />
          </div>
        </Container>
      </section>

      <section id="faq" className="scroll-mt-20 bg-surface py-16 sm:py-20">
        <Container className="max-w-3xl">
          <div className="text-center">
            <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{t("faqHeading")}</h2>
            <p className="mt-3 text-lg text-ink-muted">
              {t("faqBody")}{" "}
              <Link href="/faq" className="font-medium text-primary underline underline-offset-2">
                {t("faqLink")}
              </Link>
              .
            </p>
          </div>
          <div className="mt-10">
            <FAQAccordion faqs={homepageFaqs} />
          </div>
        </Container>
      </section>

      <CTABanner />
    </>
  );
}
